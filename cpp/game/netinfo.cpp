#include "netinfo.h"
#include "rakhook.h"
#include "raknet/BitStream.h"
#include "raknet/RakNetTypes.h"
#include "raknet/StringCompressor.h"
#include "script/script_manager.h"
#include "sync.h"
#include <chrono>

namespace {
void decompress_hp_and_armour(RakNet::BitStream* bs, std::uint8_t& hp, std::uint8_t& armour)
{
  std::uint8_t compressed_hp_armour;
  bs->Read(compressed_hp_armour);

  armour = (compressed_hp_armour & 0x0F);
  hp = (compressed_hp_armour >> 4);
  if (armour == 0xF) {
    armour = 100;
  } else {
    armour *= 7;
  }
  if (hp == 0xF) {
    hp = 100;
  } else {
    hp *= 7;
  }
}
}

void game::netinfo::process()
{
  std::chrono::steady_clock::time_point now = std::chrono::steady_clock::now();

  if (now - _last_tab_update >= std::chrono::milliseconds(3000) && rakhook::available()) {
    RakNet::BitStream bs;
    rakhook::send::rpc(RakNet::RPC_UpdateScoresPingsIPs, &bs);

    _last_tab_update = now;
  }
}

void game::netinfo::handle_outcoming_packet(std::uint8_t id, RakNet::BitStream* bs)
{
  bs->SetReadOffset(8);
  if (id == RakNet::ID_PLAYER_SYNC) {
    bs->Read(reinterpret_cast<char*>(&local_player.last_onfoot_sync), sizeof(sync::onfoot));
    return;
  }
  if (id == RakNet::ID_VEHICLE_SYNC) {
    bs->Read(reinterpret_cast<char*>(&local_player.last_vehicle_sync), sizeof(sync::vehicle));
    return;
  }
  if (id == RakNet::ID_PASSENGER_SYNC) {
    bs->Read(reinterpret_cast<char*>(&local_player.last_passenger_sync), sizeof(sync::passenger));
    return;
  }
  if (id == RakNet::ID_TRAILER_SYNC) {
    bs->Read(reinterpret_cast<char*>(&local_player.last_trailer_sync), sizeof(sync::trailer));
    return;
  }
  if (id == RakNet::ID_AIM_SYNC) {
    bs->Read(reinterpret_cast<char*>(&local_player.last_aim_sync), sizeof(sync::aim));
    return;
  }
}

bool game::netinfo::handle_outcoming_rpc(std::uint8_t id, RakNet::BitStream* bs)
{
  if (id == RakNet::RPC_ServerCommand) {
    std::uint32_t length;
    bs->ResetReadPointer();
    bs->Read(length);
    if (length < 256) {
      char cmd[256];
      bs->Read(cmd, static_cast<int>(length));
      cmd[length] = '\0';

      std::string_view sv { cmd, length };
      if (lua::script_manager::handle_command(sv)) {
        return false;
      }
    }
    return true;
  }

  if (id == RakNet::RPC_Spawn) {
    local_player.streamed_in = true;
    return true;
  }
  if (id == RakNet::RPC_Death) {
    local_player.streamed_in = false;
    return true;
  }

  if (id == RakNet::RPC_ClientJoin) {
    bs->ResetReadPointer();
    bs->IgnoreBits(32 + 8);
    std::uint8_t len;
    char nickname[256];
    bs->Read(len);
    bs->Read(nickname, len);
    nickname[len] = '\0';
    local_player.name = nickname;
    return true;
  }

  if (id == RakNet::RPC_DialogResponse) {
    std::int16_t listitem;
    std::uint8_t btn, text_len;
    char text[256];

    bs->ResetReadPointer();
    bs->IgnoreBits(16);
    bs->Read(btn);
    bs->Read(listitem);
    bs->Read(text_len);
    bs->Read(text, text_len);
    text[text_len] = '\0';

    bool was_clientside = dialog.clientside;
    dialog.shown = false;
    dialog.clientside = false;
    dialog.respond = true;
    dialog.last_button = btn;
    dialog.last_list = listitem;
    dialog.last_input = text;

    return !was_clientside;
  }

  if (id == RakNet::RPC_UpdateScoresPingsIPs) {
    RakNet::BitStream new_bs;

    new_bs.Write<std::uint16_t>(local_player_id);
    new_bs.Write<std::int32_t>(local_player.score);
    new_bs.Write<std::int32_t>(local_player.ping);

    for (auto& i : remote_players) {
      new_bs.Write<std::uint16_t>(i.second.id);
      new_bs.Write<std::int32_t>(i.second.score);
      new_bs.Write<std::int32_t>(i.second.ping);
    }

    _requested_tab = true;
    rakhook::emu::rpc(RakNet::RPC_UpdateScoresPingsIPs, &new_bs);

    return true;
  }

  return true;
}

void game::netinfo::handle_incoming_packet(std::uint8_t id, RakNet::BitStream* bs)
{
  reset_add_remove();

  if (id == RakNet::ID_CONNECTION_LOST /*|| id == RakNet::ID_DISCONNECTION_NOTIFICATION*/) {
    reset();
    return;
  }
  if (id == RakNet::ID_CONNECTION_REQUEST_ACCEPTED) {
    reset();
    bs->SetReadOffset(8 + 32 + 16);
    bs->Read(local_player_id);
    max_id = local_player_id;
    return;
  }

  if (id == RakNet::ID_PLAYER_SYNC) {
    std::uint16_t player_id;
    bs->SetReadOffset(8);
    bs->Read(player_id);

    auto it = remote_players.find(player_id);
    if (it == remote_players.end()) {
      return;
    }
    sync::onfoot& data = it->second.last_onfoot_sync;

    bool has;
    bs->Read(has);
    if (has) {
      bs->Read(data.lrAnalog);
    }
    bs->Read(has);
    if (has) {
      bs->Read(data.udAnalog);
    }

    bs->Read(data.sKeys);
    bs->Read(reinterpret_cast<char*>(data.fPosition), sizeof(data.fPosition));
    float w, x, y, z;
    bs->ReadNormQuat(w, x, y, z);
    data.fQuaternion[0] = w;
    data.fQuaternion[1] = x;
    data.fQuaternion[2] = y;
    data.fQuaternion[3] = z;
    decompress_hp_and_armour(bs, data.byteHealth, data.byteArmor);
    bs->Read(data.byteCurrentWeapon);
    bs->Read(data.byteSpecialAction);
    bs->ReadVector(x, y, z);
    data.fMoveSpeed[0] = x;
    data.fMoveSpeed[1] = y;
    data.fMoveSpeed[2] = z;

    bs->Read(has);
    if (has) {
      bs->Read(data.sSurfingVehicleID);
      bs->Read(reinterpret_cast<char*>(data.fSurfingOffsets), sizeof(data.fSurfingOffsets));
    } else {
      data.sSurfingVehicleID = -1;
    }

    bs->Read(has);
    if (has) {
      bs->Read(data.sAnimFlags);
      bs->Read(data.sCurrentAnimationID);
    } else {
      data.sAnimFlags = 0x8000;
      data.sCurrentAnimationID = 0;
    }

    it->second.reported_health = data.byteHealth;
    it->second.reported_armor = data.byteArmor;
    it->second.last_recv = std::chrono::steady_clock::now();
    return;
  }

  if (id == RakNet::ID_VEHICLE_SYNC) {
    std::uint16_t player_id;
    bs->SetReadOffset(8);
    bs->Read(player_id);

    auto it = remote_players.find(player_id);
    if (it == remote_players.end()) {
      return;
    }
    sync::vehicle& data = it->second.last_vehicle_sync;

    bs->Read(data.sVehicleID);
    bs->Read(data.lrAnalog);
    bs->Read(data.udAnalog);
    bs->Read(data.sKeys);
    float w, x, y, z;
    bs->ReadNormQuat(w, x, y, z);
    data.fQuaternion[0] = w;
    data.fQuaternion[1] = x;
    data.fQuaternion[2] = y;
    data.fQuaternion[3] = z;
    bs->Read(reinterpret_cast<char*>(data.fPosition), sizeof(data.fPosition));
    bs->ReadVector(x, y, z);
    data.fMoveSpeed[0] = x;
    data.fMoveSpeed[1] = y;
    data.fMoveSpeed[2] = z;
    std::uint16_t vehicle_hp;
    bs->Read(vehicle_hp);
    data.fVehicleHealth = vehicle_hp;
    decompress_hp_and_armour(bs, data.bytePlayerHealth, data.bytePlayerArmor);
    bs->Read(data.byteCurrentWeapon);

    bool has;
    bs->Read(has);
    if (has) {
      data.byteSiren = 1;
    }
    bs->Read(has);
    if (has) {
      data.byteLandingGearState = 1;
    }
    bs->Read(has);
    if (has) {
      bs->Read(x);
      data.fTrainSpeed = x;
    }
    bs->Read(has);
    if (has) {
      bs->Read(data.sTrailerID);
    }

    it->second.reported_health = data.bytePlayerHealth;
    it->second.reported_armor = data.bytePlayerArmor;
    it->second.last_recv = std::chrono::steady_clock::now();
    return;
  }

  if (id == RakNet::ID_PASSENGER_SYNC) {
    std::uint16_t player_id;
    bs->SetReadOffset(8);
    bs->Read(player_id);

    auto it = remote_players.find(player_id);
    if (it == remote_players.end()) {
      return;
    }

    bs->Read(reinterpret_cast<char*>(&it->second.last_passenger_sync), sizeof(sync::passenger));

    it->second.reported_health = it->second.last_passenger_sync.bytePlayerHealth;
    it->second.reported_armor = it->second.last_passenger_sync.bytePlayerArmor;
    it->second.last_recv = std::chrono::steady_clock::now();
    return;
  }
  if (id == RakNet::ID_TRAILER_SYNC) {
    std::uint16_t player_id;
    bs->SetReadOffset(8);
    bs->Read(player_id);

    auto it = remote_players.find(player_id);
    if (it == remote_players.end()) {
      return;
    }

    bs->Read(reinterpret_cast<char*>(&it->second.last_trailer_sync), sizeof(sync::trailer));
    return;
  }
  if (id == RakNet::ID_AIM_SYNC) {
    std::uint16_t player_id;
    bs->SetReadOffset(8);
    bs->Read(player_id);

    auto it = remote_players.find(player_id);
    if (it == remote_players.end()) {
      return;
    }

    bs->Read(reinterpret_cast<char*>(&it->second.last_aim_sync), sizeof(sync::aim));
    return;
  }
}

bool game::netinfo::handle_incoming_rpc(std::uint8_t id, RakNet::BitStream* bs)
{
  reset_add_remove();

  if (id == RakNet::RPC_ScrGameModeRestart) {
    reset();
    return true;
  }

  if (id == RakNet::RPC_ScrInitGame) {
    std::uint8_t len;
    char buffer[256] = "";

    bs->SetReadOffset(4 + 32 + 1 + 32 + 3 + 32 + 16 + 1 + 32 + 8 + 8 + 32 + 1 + 32 + 1 + 5 * 32);
    bs->Read(len);
    bs->Read(buffer, len);
    buffer[len] = '\0';

    hostname = buffer;
    return true;
  }

  if (id == RakNet::RPC_UpdateScoresPingsIPs) {
    bs->ResetReadPointer();
    int num_read = bs->GetNumberOfBytesUsed() / 10;
    for (int i = 0; i < num_read; ++i) {
      std::uint16_t player_id;
      std::int32_t score;
      std::int32_t ping;

      bs->Read(player_id);
      bs->Read(score);
      bs->Read(ping);

      auto it = remote_players.find(player_id);
      if (it != remote_players.end()) {
        it->second.score = score;
        it->second.ping = ping;
      }

      if (player_id == local_player_id) {
        local_player.score = score;
        local_player.ping = ping;
      }
    }

    bool receive = _requested_tab;
    _requested_tab = false;
    _last_tab_update = std::chrono::steady_clock::now();

    return receive;
  }

  if (id == RakNet::RPC_ScrServerJoin) {
    std::uint16_t player_id;
    std::uint32_t color;
    std::uint8_t is_npc;
    std::uint8_t nickname_len;
    char nickname[256];

    bs->ResetReadPointer();
    bs->Read(player_id);
    bs->Read(color);
    bs->Read(is_npc);
    bs->Read(nickname_len);
    bs->Read(nickname, nickname_len);
    nickname[nickname_len] = '\0';

    remote_players[player_id] = { player_id, nickname, is_npc == 1, color, {}, false };
    ++online;
    if (player_id > max_id) {
      max_id = player_id;
    }
    return true;
  }

  if (id == RakNet::RPC_ScrServerQuit) {
    std::uint16_t player_id;

    bs->ResetReadPointer();
    bs->Read(player_id);

    if (remote_players.erase(player_id) != 0 && online > 0) {
      --online;
    }
    player_stream_out(player_id);

    if (player_id == max_id) {
      max_id = local_player_id;
      for (auto& i : remote_players) {
        if (i.second.id > max_id) {
          max_id = i.second.id;
        }
      }
    }

    return true;
  }

  if (id == RakNet::RPC_ScrWorldPlayerAdd) {
    std::uint16_t player_id;

    bs->ResetReadPointer();
    bs->Read(player_id);

    // skip team and skin id
    bs->IgnoreBits(8 + 32);
    // skip posn
    bs->IgnoreBits(32 * 3);
    // skip facing angle
    bs->IgnoreBits(32);

    // color
    std::uint32_t color;
    bs->Read(color);

    auto it = remote_players.find(player_id);
    if (it != remote_players.end()) {
      _current_entity_type = entity_t::ped;
      _current_entity_id = player_id;
      _current_expected_remove = false;
      _current_ped_step = 0;

      it->second.color = std::rotr(color, 8);
      it->second.reported_health = 100;
      it->second.reported_armor = 0;
    }
    return true;
  }

  if (id == RakNet::RPC_ScrWorldPlayerRemove) {
    std::uint16_t player_id;

    bs->ResetReadPointer();
    bs->Read(player_id);

    auto it = remote_players.find(player_id);
    if (it != remote_players.end()) {
      _current_entity_type = entity_t::ped;
      _current_entity_id = player_id;
      _current_expected_remove = true;

      it->second.reported_health = 0;
      it->second.reported_armor = 0;
    }
    return true;
  }

  if (id == RakNet::RPC_ScrWorldVehicleAdd || id == RakNet::RPC_ScrWorldVehicleRemove) {
    std::uint16_t vehicle_id;

    bs->ResetReadPointer();
    bs->Read(vehicle_id);

    _current_entity_type = entity_t::vehicle;
    _current_entity_id = vehicle_id;
    _current_expected_remove = id == RakNet::RPC_ScrWorldVehicleRemove;
    return true;
  }

  if (id == RakNet::RPC_ScrCreateObject || id == RakNet::RPC_ScrDestroyObject) {
    std::uint16_t object_id;

    bs->ResetReadPointer();
    bs->Read(object_id);

    _current_entity_type = entity_t::object;
    _current_entity_id = object_id;
    _current_expected_remove = id == RakNet::RPC_ScrDestroyObject;
    return true;
  }

  if (id == RakNet::RPC_ScrSetPlayerColor) {
    std::uint16_t player_id;

    bs->ResetReadPointer();
    bs->Read(player_id);
    std::uint32_t color;
    bs->Read(color);

    if (player_id == local_player_id) {
      local_player.color = std::rotr(color, 8);
    } else {
      auto it = remote_players.find(player_id);
      if (it != remote_players.end())
        it->second.color = std::rotr(color, 8);
    }
    return true;
  }

  if (id == RakNet::RPC_ScrSetPlayerName) {
    std::uint16_t player_id;

    bs->ResetReadPointer();
    bs->Read(player_id);

    std::uint8_t nickname_len;
    char nickname[256];
    std::uint8_t success;
    bs->Read(nickname_len);
    bs->Read(nickname, nickname_len);
    nickname[nickname_len] = '\0';
    bs->Read(success);

    if (success) {
      if (player_id == local_player_id) {
        local_player.name = nickname;
      } else {
        auto it = remote_players.find(player_id);
        if (it != remote_players.end())
          it->second.name = nickname;
      }
    }
    return true;
  }

  if (id == RakNet::RPC_ScrShowDialog) {
    std::int16_t did;
    std::uint8_t dstyle;
    std::uint8_t title_len, button_1_len, button_2_len;
    char title[256];
    char info[4096];

    if (!dialog.pending_emulation) {
      dialog.clientside = false;
    }
    dialog.pending_emulation = false;

    bs->ResetReadPointer();
    bs->Read(did);
    if (did < 0) {
      dialog.shown = false;
      return true;
    }
    bs->Read(dstyle);
    bs->Read(title_len);
    bs->Read(title, title_len);
    title[title_len] = '\0';
    bs->Read(button_1_len);
    bs->IgnoreBits(SAMP_BYTES_TO_BITS(button_1_len));
    bs->Read(button_2_len);
    bs->IgnoreBits(SAMP_BYTES_TO_BITS(button_2_len));
    RakNet::StringCompressor::Instance()->DecodeString(info, sizeof(info), bs);

    dialog.shown = true;
    dialog.id = did;
    dialog.type = dstyle;
    dialog.caption = title;
    dialog.text = info;
    return true;
  }

  if (id == RakNet::RPC_ScrCreate3DTextLabel) {
    bs->ResetReadPointer();

    std::uint16_t labelid;
    bs->Read(labelid);
    if (labelid >= texts_3d.size()) {
      return true;
    }

    text_3d& text = texts_3d[labelid];
    text.active = true;
    bs->Read(text.color);
    bs->Read(text.x);
    bs->Read(text.y);
    bs->Read(text.z);
    bs->Read(text.distance);

    std::uint8_t test_los;
    bs->Read(test_los);
    text.ignore_walls = !test_los;

    bs->Read(text.playerid);
    bs->Read(text.vehicleid);

    char buffer[4096];
    RakNet::StringCompressor::Instance()->DecodeString(buffer, sizeof(buffer), bs);
    text.text = buffer;
    return true;
  }

  if (id == RakNet::RPC_ScrDestroy3DTextLabel) {
    bs->ResetReadPointer();

    std::uint16_t labelid;
    bs->Read(labelid);
    if (labelid >= texts_3d.size()) {
      return true;
    }

    text_3d& text = texts_3d[labelid];
    text.active = false;
    text.text.clear();
    text.text.shrink_to_fit();
    return true;
  }

  return true;
}