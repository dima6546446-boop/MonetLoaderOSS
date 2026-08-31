#include "luafuncs.h"
#include "encoding.h"
#include "game/CColPoint.h"
#include "game/CObject.h"
#include "game/CPools.h"
#include "game/CWorld.h"
#include "game/RenderWare.h"
#include "game/common.h"
#include "game/netinfo.h"
#include "game/rakhook.h"
#include "gui/imrw.h"
#include "gui/render.h"
#include "opcodes.h"
#include "raknet/BitStream.h"
#include "raknet/RakNetTypes.h"
#include "raknet/StringCompressor.h"
#include <bit>
#include <optional>

namespace {
void create_3d_text(std::uint16_t labelid, std::string_view text, std::uint32_t color, float pos_x, float pos_y, float pos_z,
    float distance, bool ignore_walls, std::uint16_t playerid, std::uint16_t vehicleid)
{
  if (labelid >= game::netinfo::texts_3d.size()) {
    return;
  }
  color = std::rotl(color, 8);

  // emulate creation for client
  RakNet::BitStream bs;
  bs.Write(labelid);
  bs.Write(color);
  bs.Write(pos_x);
  bs.Write(pos_y);
  bs.Write(pos_z);
  bs.Write(distance);
  bs.Write<std::uint8_t>(!ignore_walls);
  bs.Write(playerid);
  bs.Write(vehicleid);
  RakNet::StringCompressor::Instance()->EncodeString(text.data(), static_cast<int>(text.size() + 1), &bs);
  game::netinfo::handle_incoming_rpc(RakNet::RPC_ScrCreate3DTextLabel, &bs); // mirror changes immediately
  rakhook::emu::rpc(RakNet::RPC_ScrCreate3DTextLabel, &bs);
}

void destroy_3d_text(std::uint16_t labelid)
{
  if (labelid >= game::netinfo::texts_3d.size()) {
    return;
  }

  // emulate destruction on client
  RakNet::BitStream bs;
  bs.Write(labelid);
  game::netinfo::handle_incoming_rpc(RakNet::RPC_ScrDestroy3DTextLabel, &bs); // mirror changes immediately
  rakhook::emu::rpc(RakNet::RPC_ScrDestroy3DTextLabel, &bs);
}
}

void luafuncs::reg(sol::state& state)
{
  // state.new_usertype<RakNet::BitStream>("BitStream", sol::no_constructor);

  state["isSampAvailable"] = []() {
    return rakhook::available();
  };

  // RakNet
  state["raknetNewBitStream"] = []() {
    return new RakNet::BitStream {};
  };
  state["raknetDeleteBitStream"] = [](RakNet::BitStream* bs) {
    delete bs;
  };
  state["raknetResetBitStream"] = [](RakNet::BitStream* bs) {
    bs->Reset();
  };

  state["raknetBitStreamWriteBitStream"] = [](RakNet::BitStream* bs, RakNet::BitStream* value) {
    bs->Write(value);
  };
  state["raknetBitStreamWriteBool"] = [](RakNet::BitStream* bs, bool value) {
    bs->Write(value);
  };
  state["raknetBitStreamWriteFloat"] = [](RakNet::BitStream* bs, float value) {
    bs->Write(value);
  };
  state["raknetBitStreamWriteInt16"] = [](RakNet::BitStream* bs, std::uint16_t value) {
    bs->Write(value);
  };
  state["raknetBitStreamWriteInt32"] = [](RakNet::BitStream* bs, std::int32_t value) {
    bs->Write(value);
  };
  state["raknetBitStreamWriteInt8"] = [](RakNet::BitStream* bs, std::uint8_t value) {
    bs->Write(value);
  };
  state["raknetBitStreamWriteBuffer"] = [](RakNet::BitStream* bs, std::uintptr_t buffer, int size) {
    bs->Write(reinterpret_cast<const char*>(buffer), size);
  };
  state["raknetBitStreamWriteString"] = [](RakNet::BitStream* bs, std::string_view value) {
    bs->Write(value.data(), static_cast<int>(value.size()));
  };

  state["raknetBitStreamReadBool"] = [](RakNet::BitStream* bs) {
    bool value;
    bs->Read(value);
    return value;
  };
  state["raknetBitStreamReadFloat"] = [](RakNet::BitStream* bs) {
    float value;
    bs->Read(value);
    return value;
  };
  state["raknetBitStreamReadInt16"] = [](RakNet::BitStream* bs) {
    std::uint16_t value;
    bs->Read(value);
    return value;
  };
  state["raknetBitStreamReadInt32"] = [](RakNet::BitStream* bs) {
    std::int32_t value;
    bs->Read(value);
    return value;
  };
  state["raknetBitStreamReadInt8"] = [](RakNet::BitStream* bs) {
    std::uint8_t value;
    bs->Read(value);
    return value;
  };
  state["raknetBitStreamReadBuffer"] = [](RakNet::BitStream* bs, std::uintptr_t buffer, int size) {
    bs->Read(reinterpret_cast<char*>(buffer), size);
  };
  state["raknetBitStreamReadString"] = [](RakNet::BitStream* bs, int size) {
    std::string str;
    str.resize(size);
    bs->Read(str.data(), size);
    return str;
  };

  state["raknetBitStreamResetReadPointer"] = [](RakNet::BitStream* bs) {
    bs->ResetReadPointer();
  };
  state["raknetBitStreamResetWritePointer"] = [](RakNet::BitStream* bs) {
    bs->ResetWritePointer();
  };
  state["raknetBitStreamIgnoreBits"] = [](RakNet::BitStream* bs, int amount) {
    bs->IgnoreBits(amount);
  };
  state["raknetBitStreamSetWriteOffset"] = [](RakNet::BitStream* bs, int offset) {
    bs->SetWriteOffset(offset);
  };
  state["raknetBitStreamSetReadOffset"] = [](RakNet::BitStream* bs, int offset) {
    bs->SetReadOffset(offset);
  };
  state["raknetBitStreamGetNumberOfBitsUsed"] = [](RakNet::BitStream* bs) {
    return bs->GetNumberOfBitsUsed();
  };
  state["raknetBitStreamGetNumberOfBytesUsed"] = [](RakNet::BitStream* bs) {
    return bs->GetNumberOfBytesUsed();
  };
  state["raknetBitStreamGetNumberOfUnreadBits"] = [](RakNet::BitStream* bs) {
    return bs->GetNumberOfUnreadBits();
  };
  state["raknetBitStreamGetWriteOffset"] = [](RakNet::BitStream* bs) {
    return bs->GetWriteOffset();
  };
  state["raknetBitStreamGetReadOffset"] = [](RakNet::BitStream* bs) {
    return bs->GetReadOffset();
  };
  state["raknetBitStreamGetDataPtr"] = [](RakNet::BitStream* bs) {
    return reinterpret_cast<std::uintptr_t>(bs->GetData());
  };

  state["raknetBitStreamDecodeString"] = [](RakNet::BitStream* bs, int size) {
    std::string str;
    str.resize(size);
    RakNet::StringCompressor::Instance()->DecodeString(str.data(), size, bs);
    return str;
  };
  state["raknetBitStreamEncodeString"] = [](RakNet::BitStream* bs, std::string_view str) {
    RakNet::StringCompressor::Instance()->EncodeString(str.data(), static_cast<int>(str.size() + 1), bs);
  };

  state["raknetEmulRpcReceiveBitStream"] = [](std::uint8_t rpc, RakNet::BitStream* bs) {
    rakhook::emu::rpc(rpc, bs);
  };
  state["raknetEmulPacketReceiveBitStream"] = [](std::uint8_t packet, RakNet::BitStream* bs) {
    bs->ResetReadPointer();
    RakNet::BitStream new_bs;
    new_bs.Write(packet);
    new_bs.Write(bs);
    rakhook::emu::packet(&new_bs);
  };
  state["raknetSendRpcEx"] = [](std::uint8_t rpc, RakNet::BitStream* bs, int priority, int reliability, char channel, bool timestamp) {
    rakhook::send::rpc(rpc, bs, static_cast<RakNet::PacketPriority>(priority),
        static_cast<RakNet::PacketReliability>(reliability), channel);
  };
  state["raknetSendBitStreamEx"] = [](RakNet::BitStream* bs, int priority, int reliability, char channel) {
    rakhook::send::packet(bs, static_cast<RakNet::PacketPriority>(priority),
        static_cast<RakNet::PacketReliability>(reliability), channel);
  };
  state["raknetSendRpc"] = [](std::uint8_t rpc, RakNet::BitStream* bs) {
    rakhook::send::rpc(rpc, bs);
  };
  state["raknetSendBitStream"] = [](RakNet::BitStream* bs) {
    rakhook::send::packet(bs);
  };

  // Handle -> ID stuff
  state["sampGetCharHandleBySampPlayerId"] = [](std::uint16_t playerid) {
    CPed* ped = game::netinfo::find_ped(playerid);
    if (ped) {
      return std::tuple<bool, std::optional<int>>(true, CPools::GetPedPool()->GetRef(ped));
    }

    return std::tuple<bool, std::optional<int>>(false, std::nullopt);
  };
  state["sampGetCarHandleBySampVehicleId"] = [](std::uint16_t vehicleid) {
    CVehicle* veh = game::netinfo::find_car(vehicleid);
    if (veh) {
      return std::tuple<bool, std::optional<int>>(true, CPools::GetVehiclePool()->GetRef(veh));
    }

    return std::tuple<bool, std::optional<int>>(false, std::nullopt);
  };
  state["sampGetObjectHandleBySampId"] = [](std::uint16_t objectid) {
    CObject* obj = game::netinfo::find_object(objectid);
    if (obj) {
      return CPools::GetObjectPool()->GetRef(obj);
    }

    return -1;
  };

  state["sampGetPlayerIdByCharHandle"] = [](int self) {
    if (self == opcodes::getPlayerChar(0)) {
      return std::tuple<bool, std::optional<int>>(true, game::netinfo::local_player_id);
    }

    CPed* ped = CPools::GetPedPool()->GetAtRef(self);
    if (!ped) {
      return std::tuple<bool, std::optional<int>>(false, std::nullopt);
    }

    std::uint16_t playerid = game::netinfo::find_ped_id(ped);
    if (playerid == static_cast<std::uint16_t>(-1)) {
      return std::tuple<bool, std::optional<int>>(false, std::nullopt);
    }

    return std::tuple<bool, std::optional<int>>(true, playerid);
  };
  state["sampGetVehicleIdByCarHandle"] = [](int self) {
    CVehicle* veh = CPools::GetVehiclePool()->GetAtRef(self);
    if (!veh) {
      return std::tuple<bool, std::optional<int>>(false, std::nullopt);
    }

    std::uint16_t vehicleid = game::netinfo::find_car_id(veh);
    if (vehicleid == static_cast<std::uint16_t>(-1)) {
      return std::tuple<bool, std::optional<int>>(false, std::nullopt);
    }

    return std::tuple<bool, std::optional<int>>(true, vehicleid);
  };
  state["sampGetObjectSampIdByHandle"] = [](int self) {
    CObject* obj = CPools::GetObjectPool()->GetAtRef(self);
    if (!obj) {
      return -1;
    }

    std::uint16_t objectid = game::netinfo::find_object_id(obj);
    if (objectid == static_cast<std::uint16_t>(-1)) {
      return -1;
    }
    return static_cast<int>(objectid);
  };

  // NetInfo store stuff
  state["sampStorePlayerOnfootData"] = [](std::uint16_t playerid, std::uintptr_t buffer) {
    if (playerid == game::netinfo::local_player_id) {
      std::memcpy(reinterpret_cast<void*>(buffer), &game::netinfo::local_player.last_onfoot_sync, sizeof(game::sync::onfoot));
      return;
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      std::memcpy(reinterpret_cast<void*>(buffer), &it->second.last_onfoot_sync, sizeof(game::sync::onfoot));
    }
  };
  state["sampStorePlayerIncarData"] = [](std::uint16_t playerid, std::uintptr_t buffer) {
    if (playerid == game::netinfo::local_player_id) {
      std::memcpy(reinterpret_cast<void*>(buffer), &game::netinfo::local_player.last_vehicle_sync, sizeof(game::sync::vehicle));
      return;
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      std::memcpy(reinterpret_cast<void*>(buffer), &it->second.last_vehicle_sync, sizeof(game::sync::vehicle));
    }
  };
  state["sampStorePlayerPassengerData"] = [](std::uint16_t playerid, std::uintptr_t buffer) {
    if (playerid == game::netinfo::local_player_id) {
      std::memcpy(reinterpret_cast<void*>(buffer), &game::netinfo::local_player.last_passenger_sync, sizeof(game::sync::passenger));
      return;
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      std::memcpy(reinterpret_cast<void*>(buffer), &it->second.last_passenger_sync, sizeof(game::sync::passenger));
    }
  };
  state["sampStorePlayerTrailerData"] = [](std::uint16_t playerid, std::uintptr_t buffer) {
    if (playerid == game::netinfo::local_player_id) {
      std::memcpy(reinterpret_cast<void*>(buffer), &game::netinfo::local_player.last_trailer_sync, sizeof(game::sync::trailer));
      return;
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      std::memcpy(reinterpret_cast<void*>(buffer), &it->second.last_trailer_sync, sizeof(game::sync::trailer));
    }
  };
  state["sampStorePlayerAimData"] = [](std::uint16_t playerid, std::uintptr_t buffer) {
    if (playerid == game::netinfo::local_player_id) {
      std::memcpy(reinterpret_cast<void*>(buffer), &game::netinfo::local_player.last_aim_sync, sizeof(game::sync::aim));
      return;
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      std::memcpy(reinterpret_cast<void*>(buffer), &it->second.last_aim_sync, sizeof(game::sync::aim));
    }
  };

  // NetInfo getters
  state["sampIsLocalPlayerSpawned"] = []() {
    return game::netinfo::local_player.streamed_in;
  };

  state["sampIsPlayerConnected"] = [](std::uint16_t playerid) {
    return game::netinfo::remote_players.find(playerid) != game::netinfo::remote_players.end();
  };

  state["sampGetPlayerHealth"] = [](std::uint16_t playerid) {
    if (playerid == game::netinfo::local_player_id) {
      return static_cast<int>(CPools::GetPedPool()->GetAtRef(opcodes::getPlayerChar(0))->m_fHealth);
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      return static_cast<int>(it->second.reported_health);
    }

    return -1;
  };

  state["sampGetPlayerArmor"] = [](std::uint16_t playerid) {
    if (playerid == game::netinfo::local_player_id) {
      return static_cast<int>(CPools::GetPedPool()->GetAtRef(opcodes::getPlayerChar(0))->m_fArmour);
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      return static_cast<int>(it->second.reported_armor);
    }

    return -1;
  };

  state["sampGetPlayerPing"] = [](std::uint16_t playerid) {
    if (playerid == game::netinfo::local_player_id) {
      return game::netinfo::local_player.ping;
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      return it->second.ping;
    }

    return -1;
  };

  state["sampGetPlayerNickname"] = [](std::uint16_t playerid) {
    if (playerid == game::netinfo::local_player_id) {
      return game::netinfo::local_player.name;
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      return it->second.name;
    }

    return std::string("");
  };

  state["sampGetPlayerColor"] = [](std::uint16_t playerid) {
    if (playerid == game::netinfo::local_player_id) {
      return game::netinfo::local_player.color;
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      return it->second.color;
    }

    return static_cast<std::uint32_t>(-1);
  };

  state["sampGetPlayerAnimationId"] = [](std::uint16_t playerid) {
    if (playerid == game::netinfo::local_player_id) {
      return game::netinfo::local_player.last_onfoot_sync.sCurrentAnimationID;
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      return it->second.last_onfoot_sync.sCurrentAnimationID;
    }

    return static_cast<std::uint16_t>(0);
  };

  state["sampIsPlayerPaused"] = [](std::uint16_t playerid) {
    if (playerid == game::netinfo::local_player_id) {
      return game::IsPaused();
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      return std::chrono::steady_clock::now() - it->second.last_recv > std::chrono::milliseconds(1500);
    }

    return true;
  };

  state["sampGetPlayerSpecialAction"] = [](std::uint16_t playerid) {
    if (playerid == game::netinfo::local_player_id) {
      return game::netinfo::local_player.last_onfoot_sync.byteSpecialAction;
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      return it->second.last_onfoot_sync.byteSpecialAction;
    }

    return static_cast<std::uint8_t>(0);
  };

  state["sampIsPlayerNpc"] = [](std::uint16_t playerid) {
    if (playerid == game::netinfo::local_player_id) {
      return false;
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      return it->second.npc;
    }

    return false;
  };

  state["sampGetPlayerScore"] = [](std::uint16_t playerid) {
    if (playerid == game::netinfo::local_player_id) {
      return game::netinfo::local_player.score;
    }

    auto it = game::netinfo::remote_players.find(playerid);
    if (it != game::netinfo::remote_players.end()) {
      return it->second.score;
    }

    return -1;
  };

  state["sampGetMaxPlayerId"] = [](std::optional<bool> streamed) {
    if (!streamed.has_value() || !*streamed) {
      return game::netinfo::max_id;
    }

    return game::netinfo::find_max_streamed_ped_id();
  };
  state["sampGetPlayerCount"] = [](std::optional<bool> streamed) {
    if (!streamed.has_value() || !*streamed) {
      return game::netinfo::online;
    }

    return game::netinfo::find_streamed_ped_count();
  };

  state["sampGetCurrentServerAddress"] = []() {
    return std::tuple<std::string, std::uint16_t> { game::netinfo::address, game::netinfo::port };
  };
  state["sampGetCurrentServerName"] = []() {
    return game::netinfo::hostname;
  };

  // 3D text pool
  state["sampCreate3dText"] = [](std::string_view text, std::uint32_t color, float pos_x, float pos_y, float pos_z,
                                             float distance, bool ignore_walls, std::uint16_t playerid, std::uint16_t vehicleid) -> std::uint16_t {
    std::uint16_t labelid = -1;
    for (std::size_t i = 0; i < game::netinfo::texts_3d.size(); ++i) {
      if (!game::netinfo::texts_3d[i].active) {
        labelid = static_cast<std::uint16_t>(i);
        break;
      }
    }

    if (labelid == static_cast<std::uint16_t>(-1)) {
      return -1;
    }

    create_3d_text(labelid, text, color, pos_x, pos_y, pos_z, distance, ignore_walls, playerid, vehicleid);
    return labelid;
  };

  state["sampCreate3dTextEx"] = [](std::uint16_t labelid, std::string_view text, std::uint32_t color, float pos_x, float pos_y, float pos_z,
                                               float distance, bool ignore_walls, std::uint16_t playerid, std::uint16_t vehicleid) {
    create_3d_text(labelid, text, color, pos_x, pos_y, pos_z, distance, ignore_walls, playerid, vehicleid);
  };

  state["sampDestroy3dText"] = [](std::uint16_t labelid) {
    destroy_3d_text(labelid);
  };

  state["sampIs3dTextDefined"] = [](std::uint16_t labelid) {
    return labelid < game::netinfo::texts_3d.size() && game::netinfo::texts_3d[labelid].active;
  };

  state["sampSet3dTextString"] = [](std::uint16_t labelid, std::string_view text) {
    bool exists = labelid < game::netinfo::texts_3d.size() && game::netinfo::texts_3d[labelid].active;
    if (!exists) {
      return;
    }

    game::netinfo::text_3d& label = game::netinfo::texts_3d[labelid];
    create_3d_text(labelid, text, std::rotr(label.color, 8), label.x, label.y, label.z,
        label.distance, label.ignore_walls, label.playerid, label.vehicleid);
  };

  state["sampGet3dTextInfoById"] = [](std::uint16_t labelid) {
    using ReturnType = std::tuple<std::string, std::int32_t, float, float, float, float, bool, std::uint16_t, std::uint16_t>;
    bool exists = labelid < game::netinfo::texts_3d.size() && game::netinfo::texts_3d[labelid].active;
    if (!exists) {
      return ReturnType { "", 0, 0, 0, 0, 0, false, -1, -1 };
    }

    game::netinfo::text_3d& label = game::netinfo::texts_3d[labelid];
    return ReturnType {
      label.text, static_cast<std::int32_t>(std::rotr(label.color, 8)),
      label.x, label.y, label.z, label.distance, label.ignore_walls, label.playerid, label.vehicleid
    };
  };

  // Emulation / send
  state["sampSpawnPlayer"] = []() {
    RakNet::BitStream bs_request {};
    rakhook::send::rpc_invoke_handlers(RakNet::RPC_Spawn, &bs_request);
  };

  state["sampAddChatMessage"] = [](std::string_view text, std::uint32_t color) {
    std::uint32_t size = text.size();
    if (size > 144)
      size = 144;

    RakNet::BitStream bs;
    color <<= 8;
    color |= 0xFF;
    bs.Write(color);
    bs.Write(size);
    bs.Write(text.data(), static_cast<int>(size));
    rakhook::emu::rpc(RakNet::RPC_ScrClientMessage, &bs);
  };

  state["sampSendChat"] = [](std::string_view text) {
    if (text.length() && text[0] == '/') {
      RakNet::BitStream bs;
      bs.Write<std::uint32_t>(text.size());
      bs.Write(text.data(), static_cast<int>(text.size()));
      rakhook::send::rpc(RakNet::RPC_ServerCommand, &bs);
    } else {
      RakNet::BitStream bs;
      bs.Write<std::uint8_t>(text.size());
      bs.Write(text.data(), static_cast<int>(text.size()));
      rakhook::send::rpc(RakNet::RPC_Chat, &bs);
    }
  };

  state["sampProcessChatInput"] = [](std::string_view text) {
    if (text.length() && text[0] == '/') {
      RakNet::BitStream bs;
      bs.Write<std::uint32_t>(text.size());
      bs.Write(text.data(), static_cast<int>(text.size()));
      rakhook::send::rpc_invoke_handlers(RakNet::RPC_ServerCommand, &bs);
    } else {
      RakNet::BitStream bs;
      bs.Write<std::uint8_t>(text.size());
      bs.Write(text.data(), static_cast<int>(text.size()));
      rakhook::send::rpc_invoke_handlers(RakNet::RPC_Chat, &bs);
    }
  };

  state["sampRequestClass"] = [](std::uint32_t classid) {
    RakNet::BitStream bs {};
    bs.Write(classid);
    rakhook::send::rpc(RakNet::RPC_RequestClass, &bs);
  };

  state["sampSendScmEvent"] = [](std::uint32_t event, std::uint32_t id, std::int32_t param1, std::int32_t param2) {
    RakNet::BitStream bs {};
    bs.Write(event);
    bs.Write(id);
    bs.Write(param1);
    bs.Write(param2);

    rakhook::send::rpc(RakNet::RPC_ScmEvent, &bs);
  };

  state["sampSetSpecialAction"] = [](std::uint8_t action) {
    RakNet::BitStream bs {};
    bs.Write(action);

    rakhook::emu::rpc(RakNet::RPC_ScrSetPlayerSpecialAction, &bs);
  };

  state["sampSendDeathByPlayer"] = [](std::uint16_t playerid, std::uint8_t reason) {
    RakNet::BitStream bs {};
    bs.Write(reason);
    bs.Write(playerid);

    rakhook::send::rpc(RakNet::RPC_Death, &bs);
  };

  state["sampSendEnterVehicle"] = [](std::uint16_t id, bool passenger) {
    RakNet::BitStream bs {};
    bs.Write(id);
    bs.Write<std::uint8_t>(passenger);
    rakhook::send::rpc(RakNet::RPC_EnterVehicle, &bs);
  };

  state["sampSendExitVehicle"] = [](std::uint16_t id) {
    RakNet::BitStream bs {};
    bs.Write(id);
    rakhook::send::rpc(RakNet::RPC_ExitVehicle, &bs);
  };

  state["sampSendSpawn"] = []() {
    RakNet::BitStream bs {};
    rakhook::send::rpc(RakNet::RPC_Spawn, &bs);
  };

  state["sampSendDamageVehicle"] = [](std::uint16_t id, std::int32_t panel, std::int32_t doors, std::uint8_t lights, std::uint8_t tires) {
    RakNet::BitStream bs {};
    bs.Write(id);
    bs.Write(panel);
    bs.Write(doors);
    bs.Write(lights);
    bs.Write(tires);
    rakhook::send::rpc(RakNet::RPC_DamageVehicle, &bs);
  };

  state["sampSendRconCommand"] = [](std::string_view cmd) {
    RakNet::BitStream bs {};
    bs.Write<std::uint8_t>(RakNet::ID_RCON_COMMAND);
    bs.Write<std::uint32_t>(cmd.size());
    bs.Write(cmd.data(), static_cast<int>(cmd.size()));
    rakhook::send::packet(&bs);
  };
  state["sampSendOnfootData"] = [](std::uintptr_t data) {
    RakNet::BitStream bs {};
    bs.Write<std::uint8_t>(RakNet::ID_PLAYER_SYNC);
    bs.Write(reinterpret_cast<const char*>(data), sizeof(game::sync::onfoot));
    rakhook::send::packet(&bs);
  };
  state["sampSendIncarData"] = [](std::uintptr_t data) {
    RakNet::BitStream bs {};
    bs.Write<std::uint8_t>(RakNet::ID_VEHICLE_SYNC);
    bs.Write(reinterpret_cast<const char*>(data), sizeof(game::sync::vehicle));
    rakhook::send::packet(&bs);
  };
  state["sampSendPassengerData"] = [](std::uintptr_t data) {
    RakNet::BitStream bs {};
    bs.Write<std::uint8_t>(RakNet::ID_PASSENGER_SYNC);
    bs.Write(reinterpret_cast<const char*>(data), sizeof(game::sync::passenger));
    rakhook::send::packet(&bs);
  };
  state["sampSendAimData"] = [](std::uintptr_t data) {
    RakNet::BitStream bs {};
    bs.Write<std::uint8_t>(RakNet::ID_AIM_SYNC);
    bs.Write(reinterpret_cast<const char*>(data), sizeof(game::sync::aim));
    rakhook::send::packet(&bs);
  };
  state["sampSendBulletData"] = [](std::uintptr_t data) {
    RakNet::BitStream bs {};
    bs.Write<std::uint8_t>(RakNet::ID_BULLET_SYNC);
    bs.Write(reinterpret_cast<const char*>(data), sizeof(game::sync::bullet));
    rakhook::send::packet(&bs);
  };
  state["sampSendTrailerData"] = [](std::uintptr_t data) {
    RakNet::BitStream bs {};
    bs.Write<std::uint8_t>(RakNet::ID_TRAILER_SYNC);
    bs.Write(reinterpret_cast<const char*>(data), sizeof(game::sync::trailer));
    rakhook::send::packet(&bs);
  };
  state["sampSendUnoccupiedData"] = [](std::uintptr_t data) {
    RakNet::BitStream bs {};
    bs.Write<std::uint8_t>(RakNet::ID_UNOCCUPIED_SYNC);
    bs.Write(reinterpret_cast<const char*>(data), sizeof(game::sync::unoccupied));
    rakhook::send::packet(&bs);
  };
  state["sampSendSpectatorData"] = [](std::uintptr_t data) {
    RakNet::BitStream bs {};
    bs.Write<std::uint8_t>(RakNet::ID_SPECTATOR_SYNC);
    bs.Write(reinterpret_cast<const char*>(data), sizeof(game::sync::spectator));
    rakhook::send::packet(&bs);
  };

  state["sampSendClickPlayer"] = [](std::uint16_t playerid, std::uint8_t source) {
    RakNet::BitStream bs {};
    bs.Write(playerid);
    bs.Write(source);
    rakhook::send::rpc(RakNet::RPC_ClickPlayer, &bs);
  };

  state["sampSendDialogResponse"] = [](std::uint16_t id, std::uint8_t button, std::int16_t listitem, std::string_view input) {
    RakNet::BitStream bs;
    bs.Write(id);
    bs.Write(button);
    bs.Write(listitem);
    bs.Write<std::uint8_t>(input.size());
    bs.Write(input.data(), static_cast<int>(input.size()));
    rakhook::send::rpc(RakNet::RPC_DialogResponse, &bs);
  };

  state["sampSendClickTextdraw"] = [](std::uint16_t id) {
    RakNet::BitStream bs {};
    bs.Write(id);
    rakhook::send::rpc(RakNet::RPC_ClickTextDraw, &bs);
  };

  state["sampSendGiveDamage"] = [](std::uint16_t id, float damage, std::int32_t weapon, std::int32_t bodyPart) {
    RakNet::BitStream bs {};
    bs.Write(false);
    bs.Write(id);
    bs.Write(damage);
    bs.Write(weapon);
    bs.Write(bodyPart);
    rakhook::send::rpc(RakNet::RPC_GiveTakeDamage, &bs);
  };
  state["sampSendTakeDamage"] = [](std::uint16_t id, float damage, std::int32_t weapon, std::int32_t bodyPart) {
    RakNet::BitStream bs {};
    bs.Write(true);
    bs.Write(id);
    bs.Write(damage);
    bs.Write(weapon);
    bs.Write(bodyPart);
    rakhook::send::rpc(RakNet::RPC_GiveTakeDamage, &bs);
  };

  state["sampSendEditObject"] = [](bool playerObject, std::uint16_t objectId, std::int32_t response,
                                               float posX, float posY, float posZ,
                                               float rotX, float rotY, float rotZ) {
    RakNet::BitStream bs {};
    bs.Write(playerObject);
    bs.Write(objectId);
    bs.Write(response);
    bs.Write(posX);
    bs.Write(posY);
    bs.Write(posZ);
    bs.Write(rotX);
    bs.Write(rotY);
    bs.Write(rotZ);
    rakhook::send::rpc(RakNet::RPC_EditObject, &bs);
  };

  state["sampSendEditAttachedObject"] = [](std::int32_t response, std::int32_t index, std::int32_t model, std::int32_t bone,
                                                       float posX, float posY, float posZ,
                                                       float rotX, float rotY, float rotZ,
                                                       float scaleX, float scaleY, float scaleZ) {
    RakNet::BitStream bs {};
    bs.Write(response);
    bs.Write(index);
    bs.Write(model);
    bs.Write(bone);
    bs.Write(posX);
    bs.Write(posY);
    bs.Write(posZ);
    bs.Write(rotX);
    bs.Write(rotY);
    bs.Write(rotZ);
    bs.Write(scaleX);
    bs.Write(scaleY);
    bs.Write(scaleZ);
    bs.Write<int32_t>(0);
    bs.Write<int32_t>(0);
    rakhook::send::rpc(RakNet::RPC_EditAttachedObject, &bs);
  };

  state["sampSendInteriorChange"] = [](std::uint8_t id) {
    RakNet::BitStream bs {};
    bs.Write(id);
    rakhook::send::rpc(RakNet::RPC_SetInteriorId, &bs);
  };

  state["sampSendRequestSpawn"] = []() {
    RakNet::BitStream bs {};
    rakhook::send::rpc(RakNet::RPC_RequestSpawn, &bs);
  };

  state["sampSendPickedUpPickup"] = [](std::int32_t id) {
    RakNet::BitStream bs {};
    bs.Write(id);
    rakhook::send::rpc(RakNet::RPC_PickedUpPickup, &bs);
  };

  state["sampSendMenuSelectRow"] = [](std::uint8_t id) {
    RakNet::BitStream bs {};
    bs.Write(id);
    rakhook::send::rpc(RakNet::RPC_MenuSelect, &bs);
  };

  state["sampSendMenuQuit"] = []() {
    RakNet::BitStream bs {};
    rakhook::send::rpc(RakNet::RPC_MenuQuit, &bs);
  };

  state["sampSendVehicleDestroyed"] = [](std::uint16_t id) {
    RakNet::BitStream bs {};
    bs.Write(id);
    rakhook::send::rpc(RakNet::RPC_VehicleDestroyed, &bs);
  };

  // Dialogs
  state["sampShowDialog"] = [](std::int16_t id, std::string_view caption, std::string_view text, std::string_view button1, std::string_view button2, std::uint8_t style) {
    game::netinfo::dialog.pending_emulation = true;
    game::netinfo::dialog.clientside = true;
    game::netinfo::dialog.shown = true;
    game::netinfo::dialog.id = id;
    game::netinfo::dialog.type = style;
    game::netinfo::dialog.caption = caption;
    game::netinfo::dialog.text = text;

    RakNet::BitStream bs;
    bs.Write(id);
    bs.Write(style);
    bs.Write<std::uint8_t>(caption.size());
    bs.Write(caption.data(), static_cast<int>(caption.size()));
    bs.Write<std::uint8_t>(button1.size());
    bs.Write(button1.data(), static_cast<int>(button1.size()));
    bs.Write<std::uint8_t>(button2.size());
    bs.Write(button2.data(), static_cast<int>(button2.size()));
    RakNet::StringCompressor::Instance()->EncodeString(text.data(), static_cast<int>(text.size() + 1), &bs);
    rakhook::emu::rpc(RakNet::RPC_ScrShowDialog, &bs);
  };
  state["sampHasDialogRespond"] = [](std::int16_t id) -> std::tuple<bool, int, int, std::string> {
    if (game::netinfo::dialog.id != id || !game::netinfo::dialog.respond) {
      return { false, 0, 0, "" };
    };
    game::netinfo::dialog.respond = false;
    return { true, game::netinfo::dialog.last_button, game::netinfo::dialog.last_list, game::netinfo::dialog.last_input };
  };
  state["sampIsDialogActive"] = []() {
    return game::netinfo::dialog.shown;
  };
  state["sampGetCurrentDialogType"] = []() {
    return game::netinfo::dialog.type;
  };
  state["sampGetCurrentDialogId"] = []() {
    return game::netinfo::dialog.id;
  };
  state["sampGetDialogText"] = []() {
    return game::netinfo::dialog.text;
  };
  state["sampGetDialogCaption"] = []() {
    return game::netinfo::dialog.caption;
  };
  state["sampSetDialogClientside"] = [](bool clientside) {
    game::netinfo::dialog.clientside = clientside;
  };
  state["sampIsDialogClientside"] = []() {
    return game::netinfo::dialog.clientside;
  };

  // Utilities
  state["getScreenResolution"] = []() {
    auto* rs = rw::RsGlobal();
    return std::tuple<int, int>(rs->screenWidth, rs->screenHeight);
  };
  state["convert3DCoordsToScreen"] = [](float x, float y, float z) {
    game::ScreenCoors result = game::CalcScreenCoors(CVector { x, y, z });
    return std::tuple<float, float>(result.pos.x, result.pos.y);
  };
  state["convert3DCoordsToScreenEx"] = [](float x, float y, float z,
                                                      std::optional<bool> check_min, std::optional<bool> check_max) {
    if (!check_min.has_value()) {
      check_min = false;
    }
    if (!check_max.has_value()) {
      check_max = false;
    }
    game::ScreenCoors result = game::CalcScreenCoors(CVector { x, y, z }, *check_min, *check_max);
    return std::tuple<bool, float, float, float, float, float>(result.result, result.pos.x, result.pos.y, result.pos.z, result.scale_x, result.scale_y);
  };
  state["convertScreenCoordsToWorld3D"] = [](float x, float y, float z) {
    CVector result = game::CalcWorldCoors(CVector { x, y, z });
    return std::tuple<float, float, float>(result.x, result.y, result.z);
  };
  state["convertGameScreenCoordsToWindowScreenCoords"] = [](float gx, float gy) {
    return std::tuple<float, float>(
        gx / 640.f * static_cast<float>(rw::RsGlobal()->screenWidth),
        gy / 448.f * static_cast<float>(rw::RsGlobal()->screenHeight));
  };
  state["convertWindowScreenCoordsToGameScreenCoords"] = [](float wx, float wy) {
    return std::tuple<float, float>(
        wx / static_cast<float>(rw::RsGlobal()->screenWidth) * 640.f,
        wy / static_cast<float>(rw::RsGlobal()->screenHeight) * 448.f);
  };

  state["processLineOfSight"] = [](sol::this_state state, float origin_x, float origin_y, float origin_z, float target_x, float target_y, float target_z,
                                               std::optional<bool> check_solid, std::optional<bool> car, std::optional<bool> ped, std::optional<bool> object, std::optional<bool> particle,
                                               std::optional<bool> see_through, std::optional<bool> ignore_some_objects, std::optional<bool> shot_through) {
    if (!check_solid.has_value()) {
      check_solid = true;
    }
    if (!car.has_value()) {
      car = false;
    }
    if (!ped.has_value()) {
      ped = false;
    }
    if (!object.has_value()) {
      object = false;
    }
    if (!particle.has_value()) {
      particle = false;
    }
    if (!see_through.has_value()) {
      see_through = false;
    }
    if (!ignore_some_objects.has_value()) {
      ignore_some_objects = false;
    }
    if (!shot_through.has_value()) {
      shot_through = false;
    }

    bool result;
    sol::table data { state, sol::create };
    CVector start { origin_x, origin_y, origin_z };
    CVector end { target_x, target_y, target_z };
    CColPoint col_point;
    CEntity* entity = nullptr;
    result = CWorld::ProcessLineOfSight(start, end, col_point, entity,
        *check_solid, *car, *ped, *object, *particle,
        *see_through, *ignore_some_objects, *shot_through);
    if (!result) {
      return std::tuple<bool, sol::object>(result, sol::lua_nil);
    }

#define GET_OR_CREATE(parent, name) (parent).get_or(name, (parent).create_named(name))
    sol::table pos = GET_OR_CREATE(data, "pos");
    pos[1] = col_point.m_vecPosition.x;
    pos[2] = col_point.m_vecPosition.y;
    pos[3] = col_point.m_vecPosition.z;
    sol::table normal = GET_OR_CREATE(data, "normal");
    normal[1] = col_point.m_vecNormal.x;
    normal[2] = col_point.m_vecNormal.y;
    normal[3] = col_point.m_vecNormal.z;
    sol::table surface_type = GET_OR_CREATE(data, "surfaceType");
    surface_type[1] = col_point.m_dataA.m_nSurfaceType;
    surface_type[2] = col_point.m_dataB.m_nSurfaceType;
    sol::table piece_type = GET_OR_CREATE(data, "pieceType");
    piece_type[1] = col_point.m_dataA.m_nPieceType;
    piece_type[2] = col_point.m_dataB.m_nPieceType;
    data["depth"] = col_point.m_fDepth;
    data["entity"] = reinterpret_cast<std::uintptr_t>(entity);
    data["entityType"] = entity ? entity->m_nType : static_cast<int>(ENTITY_TYPE_NOTHING);
#undef GET_OR_CREATE
    return std::tuple<bool, sol::object>(result, data);
  };

  // Render
  state["renderDrawLine"] = [](float pos1X, float pos1Y, float pos2X, float pos2Y, float width, std::uint32_t color) {
    gui::render::draw_line(pos1X, pos1Y, pos2X, pos2Y, width, color);
  };
  state["renderDrawBox"] = [](float posX, float posY, float sizeX, float sizeY, std::uint32_t color) {
    gui::render::draw_box(posX, posY, sizeX, sizeY, color);
  };
  state["renderDrawBoxWithBorder"] = [](float posX, float posY, float sizeX, float sizeY, std::uint32_t color, float bsize, std::uint32_t bcolor) {
    gui::render::draw_box_with_border(posX, posY, sizeX, sizeY, color, bsize, bcolor);
  };
  state["renderDrawPolygon"] = [](float posX, float posY, float sizeX, float sizeY, int corners, float rotation, std::uint32_t color) {
    gui::render::draw_polygon(posX, posY, sizeX, sizeY, corners, rotation, color);
  };

  state["renderLoadTextureFromFile"] = [](const char* file) {
    return imrw::load_image(file).raster;
  };
  state["renderLoadTextureFromFileInMemory"] = [](std::uintptr_t ptr, int len) {
    return imrw::load_image_from_memory(reinterpret_cast<unsigned char*>(ptr), len).raster;
  };
  state["renderReleaseTexture"] = [](ImTextureID raster) {
    imrw::destroy_image(raster);
  };
  state["renderGetTextureSize"] = [](ImTextureID raster) {
    imrw::image_data data = imrw::get_image_data(raster);
    return std::tuple<float, float>(data.width, data.height);
  };
  state["renderDrawTexture"] = [](ImTextureID raster, float posX, float posY, float sizeX, float sizeY, float rotation, std::uint32_t color) {
    gui::render::draw_image(raster, posX, posY, sizeX, sizeY, rotation, color);
  };

  state["renderGetFontDrawTextLength"] = [](std::int32_t font, std::string_view text, std::optional<bool> ignore_color_tags) {
    std::string recoded = encoding::cp1251_to_utf8(text);
    return gui::render::get_text_length(font, recoded, ignore_color_tags.has_value() ? *ignore_color_tags : false);
  };
  state["renderGetFontDrawHeight"] = [](std::int32_t font) {
    return gui::render::get_font_height(font);
  };
  state["renderCreateFont"] = [](const char* font, float height, std::uint32_t flags, std::optional<std::uint32_t> charset) {
    return gui::render::get_font(static_cast<int>(height), flags & 4); // 4 - SF outline flag
  };
  state["renderReleaseFont"] = [](std::int32_t font) {};
  state["renderFontDrawText"] = [](std::int32_t font, std::string_view text, float posX, float posY, std::uint32_t color, std::optional<bool> ignore_color_tags) {
    std::string recoded = encoding::cp1251_to_utf8(text);
    gui::render::draw_font(font, recoded, posX, posY, color, ignore_color_tags.has_value() ? *ignore_color_tags : false);
  };
}