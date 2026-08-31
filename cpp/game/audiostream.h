#pragma once
#include "bass.h"
#include "bass_manager.h"
#include <cstddef>
#include <cstdint>

namespace game {
namespace audiostream {
  enum state {
    STOP = 0,
    PLAY = 1,
    PAUSE = 2,
    RESUME = 3
  };

  enum status {
    STOPPED = -1,
    PLAYING = 1,
    PAUSED = 2
  };

  inline HSTREAM create(const char* path, bool is_3d = false)
  {
    if (!bass_manager::inited) {
      return 0;
    }
    bass_manager::context ctx {};

    std::uint32_t flags = is_3d ? (BASS_SAMPLE_MONO | BASS_SAMPLE_3D) : 0;
    HSTREAM stream = BASS_StreamCreateFile(0, path, 0, 0, flags);
    if (stream == 0) {
      stream = BASS_StreamCreateURL(path, 0, flags, nullptr, nullptr);
    }

    if (is_3d) {
      // we use relative in order to not fuck up arizona
      BASS_ChannelSet3DAttributes(stream, BASS_3DMODE_RELATIVE, 0.0f, 0.0f, -1, -1, -1);
    }
    return stream;
  }

  inline HSTREAM create(const void* memory, std::size_t length, bool is_3d = false)
  {
    if (!bass_manager::inited) {
      return 0;
    }
    bass_manager::context ctx {};

    std::uint32_t flags = is_3d ? (BASS_SAMPLE_MONO | BASS_SAMPLE_3D) : 0;

    HSTREAM stream = BASS_StreamCreateFile(1, memory, 0, length, flags);
    if (is_3d) {
      // we use relative in order to not fuck up arizona
      BASS_ChannelSet3DAttributes(stream, BASS_3DMODE_RELATIVE, 0.0f, 0.0f, -1, -1, -1);
    }

    return stream;
  }

  inline void release(HSTREAM stream)
  {
    if (!bass_manager::inited) {
      return;
    }
    bass_manager::context ctx {};

    if (stream != 0) {
      BASS_StreamFree(stream);
    }
  }

  inline void set_state(HSTREAM handle, state st)
  {
    if (!bass_manager::inited) {
      return;
    }
    bass_manager::context ctx {};

    switch (st) {
    case STOP: {
      BASS_ChannelStop(handle);
      break;
    }
    case PLAY: {
      BASS_ChannelPlay(handle, 1);
      break;
    }
    case PAUSE: {
      BASS_ChannelPause(handle);
      break;
    }
    case RESUME: {
      BASS_ChannelPlay(handle, 0);
      break;
    }
    }
  }

  inline status get_state(HSTREAM handle)
  {
    if (!bass_manager::inited) {
      return STOPPED;
    }
    bass_manager::context ctx {};

    switch (BASS_ChannelIsActive(handle)) {
    case BASS_ACTIVE_STOPPED: {
      return STOPPED;
    }
    case BASS_ACTIVE_PAUSED:
    case BASS_ACTIVE_PAUSED_DEVICE: {
      return PAUSED;
    }
    case BASS_ACTIVE_PLAYING:
    case BASS_ACTIVE_STALLED: {
      return PLAYING;
    }
    default: {
      return STOPPED;
    }
    }
  }

  inline void set_volume(HSTREAM handle, float volume)
  {
    if (!bass_manager::inited) {
      return;
    }
    bass_manager::context ctx {};

    BASS_ChannelSetAttribute(handle, BASS_ATTRIB_VOL, volume);
  }

  inline float get_volume(HSTREAM handle)
  {
    if (!bass_manager::inited) {
      return 0.f;
    }
    bass_manager::context ctx {};

    float v { 0.f };
    BASS_ChannelGetAttribute(handle, BASS_ATTRIB_VOL, &v);
    return v;
  }

  inline void set_looped(HSTREAM handle, bool looped)
  {
    if (!bass_manager::inited) {
      return;
    }
    bass_manager::context ctx {};

    BASS_ChannelFlags(handle, looped ? BASS_SAMPLE_LOOP : 0, BASS_SAMPLE_LOOP);
  }

  inline bool get_looped(HSTREAM handle)
  {
    if (!bass_manager::inited) {
      return false;
    }
    bass_manager::context ctx {};

    return BASS_ChannelFlags(handle, 0, 0) & BASS_SAMPLE_LOOP;
  }

  inline void set_pos(HSTREAM handle, double pos)
  {
     if (!bass_manager::inited) {
      return;
    }
    bass_manager::context ctx {};

    BASS_ChannelSetPosition(handle, BASS_ChannelSeconds2Bytes(handle, pos), BASS_POS_BYTE);
  }

  inline double get_length(HSTREAM handle)
  {
    if (!bass_manager::inited) {
      return 0.f;
    }
    bass_manager::context ctx {};

    return BASS_ChannelBytes2Seconds(handle, BASS_ChannelGetLength(handle, BASS_POS_BYTE));
  }
};
}