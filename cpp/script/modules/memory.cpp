#include "memory.h"
#include "utils/str.h"
#include <cstring>
#include <sys/mman.h>
#include <unistd.h>

namespace {
void protect_memory(void* dest, std::size_t size, int prot)
{
  static std::size_t page_size = sysconf(_SC_PAGE_SIZE);
  static auto page_size_mask = ~static_cast<uintptr_t>(page_size - 1);

  void* start = reinterpret_cast<void*>(reinterpret_cast<uintptr_t>(dest) & page_size_mask);
  std::size_t page_count = (reinterpret_cast<std::uintptr_t>(dest) + size - reinterpret_cast<std::uintptr_t>(start) + page_size - 1) / page_size;
  std::size_t protect_size = page_size * page_count;

  mprotect(start, protect_size, prot);
  __builtin___clear_cache(reinterpret_cast<char*>(start), reinterpret_cast<char*>(reinterpret_cast<std::uintptr_t>(start) + protect_size));
}

std::uint8_t char_to_hex(const char c)
{
  if (c >= '0' && c <= '9')
    return static_cast<std::uint8_t>(c - '0');
  else {
    char lower = c | 0x20; // ASCII hack to convert to lower case
    return static_cast<std::uint8_t>(lower - 'a' + 10);
  }
}
}

void lua::memory::write(std::uintptr_t address, std::size_t size, std::int32_t value, std::optional<bool> unprotect)
{
  if (size < 1 || size > 4) {
    return;
  }
  if (unprotect.has_value() && *unprotect) {
    protect_memory(reinterpret_cast<void*>(address), size, PROT_READ | PROT_WRITE | PROT_EXEC);
  }

  std::memcpy(reinterpret_cast<void*>(address), &value, size); // lil' endian
}

std::int32_t lua::memory::read(std::uintptr_t address, std::size_t size, std::optional<bool> unprotect)
{
  if (size < 1 || size > 4) {
    return 0;
  }
  if (unprotect.has_value() && *unprotect) {
    protect_memory(reinterpret_cast<void*>(address), size, PROT_READ | PROT_WRITE | PROT_EXEC);
  }

  std::int32_t value {};
  std::memcpy(&value, reinterpret_cast<void*>(address), size); // lil' endian
  return value;
}

void lua::memory::write64(std::uintptr_t address, double value, bool unsign, std::optional<bool> unprotect)
{
  if (unprotect.has_value() && *unprotect) {
    protect_memory(reinterpret_cast<void*>(address), sizeof(std::int64_t), PROT_READ | PROT_WRITE | PROT_EXEC);
  }

  if (unsign) {
    auto u = static_cast<std::uint64_t>(value);
    std::memcpy(reinterpret_cast<void*>(address), &u, sizeof(u));
  } else {
    auto i = static_cast<std::int64_t>(value);
    std::memcpy(reinterpret_cast<void*>(address), &i, sizeof(i));
  }
}

double lua::memory::read64(std::uintptr_t address, bool unsign, std::optional<bool> unprotect)
{
  if (unprotect.has_value() && *unprotect) {
    protect_memory(reinterpret_cast<void*>(address), sizeof(std::int64_t), PROT_READ | PROT_WRITE | PROT_EXEC);
  }

  if (unsign) {
    std::uint64_t u;
    std::memcpy(&u, reinterpret_cast<void*>(address), sizeof(u));
    return static_cast<double>(u);
  } else {
    std::int64_t i;
    std::memcpy(&i, reinterpret_cast<void*>(address), sizeof(i));
    return static_cast<double>(i);
  }
}

void lua::memory::unprotect(std::uintptr_t address, std::size_t size)
{
  protect_memory(reinterpret_cast<void*>(address), size, PROT_READ | PROT_WRITE | PROT_EXEC);
}

void lua::memory::copy(std::uintptr_t dst, std::uintptr_t src, std::size_t size, std::optional<bool> unprotect)
{
  if (unprotect.has_value() && *unprotect) {
    protect_memory(reinterpret_cast<void*>(dst), size, PROT_READ | PROT_WRITE | PROT_EXEC);
  }
  std::memcpy(reinterpret_cast<void*>(dst), reinterpret_cast<void*>(src), size);
}

bool lua::memory::compare(std::uintptr_t a, std::uintptr_t b, std::size_t size)
{
  return !std::memcmp(reinterpret_cast<void*>(a), reinterpret_cast<void*>(b), size);
}

void lua::memory::fill(std::uintptr_t address, int value, std::size_t size, std::optional<bool> unprotect)
{
  if (unprotect.has_value() && *unprotect) {
    protect_memory(reinterpret_cast<void*>(address), size, PROT_READ | PROT_WRITE | PROT_EXEC);
  }

  std::memset(reinterpret_cast<void*>(address), value, size);
}

void lua::memory::write_hex(const char* hex, std::uintptr_t address, std::size_t size, std::optional<bool> unprotect)
{
  if (unprotect.has_value() && *unprotect) {
    protect_memory(reinterpret_cast<void*>(address), size, PROT_READ | PROT_WRITE | PROT_EXEC);
  }

  std::size_t idx {};
  int read {};
  std::uint8_t temp_byte {};
  while (*hex && idx < size) {
    char i = *hex;
    if (i != ' ' && i != '\t' && i != '\n') {
      if (read == 0) {
        temp_byte |= char_to_hex(i) << 4;
      } else {
        temp_byte |= char_to_hex(i);
      }
      ++read;
    }

    if (read == 2) {
      std::memcpy(reinterpret_cast<void*>(address + idx), &temp_byte, 1);
      ++idx;
      temp_byte = 0;
      read = 0;
    }
    ++hex;
  }
}

std::string lua::memory::hex_to_data(const std::string& hex)
{
  int read {};
  std::uint8_t temp_byte {};
  std::string result;
  result.reserve(hex.size() / 2);

  for (char i : hex) {
    if (i != ' ' && i != '\t' && i != '\n') {
      if (read == 0) {
        temp_byte |= char_to_hex(i) << 4;
      } else {
        temp_byte |= char_to_hex(i);
      }
      ++read;
    }

    if (read == 2) {
      result += static_cast<char>(temp_byte);
      temp_byte = 0;
      read = 0;
    }
  }

  return result;
}

sol::table lua::memory::reg(sol::this_state st)
{
  sol::state_view state { st };
  sol::table m = state.create_table();

  m["write"] = &memory::write;
  m["read"] = &memory::read;

  m["getint8"] = [](std::uintptr_t address, std::optional<bool> unprotect) {
    return static_cast<std::int8_t>(memory::read(address, sizeof(std::int8_t), unprotect));
  };
  m["getint16"] = [](std::uintptr_t address, std::optional<bool> unprotect) {
    return static_cast<std::int16_t>(memory::read(address, sizeof(std::int16_t), unprotect));
  };
  m["getint32"] = [](std::uintptr_t address, std::optional<bool> unprotect) {
    return static_cast<std::int32_t>(memory::read(address, sizeof(std::int32_t), unprotect));
  };
  m["getint64"] = [](std::uintptr_t address, std::optional<bool> unprotect) {
    return memory::read64(address, false, unprotect);
  };

  m["getuint8"] = [](std::uintptr_t address, std::optional<bool> unprotect) {
    return static_cast<std::uint8_t>(memory::read(address, sizeof(std::uint8_t), unprotect));
  };
  m["getuint16"] = [](std::uintptr_t address, std::optional<bool> unprotect) {
    return static_cast<std::uint16_t>(memory::read(address, sizeof(std::uint16_t), unprotect));
  };
  m["getuint32"] = [](std::uintptr_t address, std::optional<bool> unprotect) {
    return static_cast<std::uint32_t>(memory::read(address, sizeof(std::uint32_t), unprotect));
  };
  m["getuint64"] = [](std::uintptr_t address, std::optional<bool> unprotect) {
    return memory::read64(address, true, unprotect);
  };

  m["setint8"] = [](std::uintptr_t address, std::int32_t value, std::optional<bool> unprotect) {
    memory::write(address, sizeof(std::int8_t), value, unprotect);
    return true;
  };
  m["setint16"] = [](std::uintptr_t address, std::int32_t value, std::optional<bool> unprotect) {
    memory::write(address, sizeof(std::int16_t), value, unprotect);
    return true;
  };
  m["setint32"] = [](std::uintptr_t address, std::int32_t value, std::optional<bool> unprotect) {
    memory::write(address, sizeof(std::int32_t), value, unprotect);
    return true;
  };
  m["setint64"] = [](std::uintptr_t address, double value, std::optional<bool> unprotect) {
    memory::write64(address, value, false, unprotect);
    return true;
  };

  m["setuint8"] = [](std::uintptr_t address, std::int32_t value, std::optional<bool> unprotect) {
    memory::write(address, sizeof(std::int8_t), value, unprotect);
    return true;
  };
  m["setuint16"] = [](std::uintptr_t address, std::int32_t value, std::optional<bool> unprotect) {
    memory::write(address, sizeof(std::int16_t), value, unprotect);
    return true;
  };
  m["setuint32"] = [](std::uintptr_t address, std::int32_t value, std::optional<bool> unprotect) {
    memory::write(address, sizeof(std::int32_t), value, unprotect);
    return true;
  };
  m["setuint64"] = [](std::uintptr_t address, double value, std::optional<bool> unprotect) {
    memory::write64(address, value, true, unprotect);
    return true;
  };

  m["getfloat"] = [](std::uintptr_t address, std::optional<bool> unprotect) {
    std::uint32_t i = memory::read(address, sizeof(i), unprotect);
    float f;
    std::memcpy(&f, &i, sizeof(f));
    return f;
  };
  m["getdouble"] = [](std::uintptr_t address, std::optional<bool> unprotect) {
    std::uint32_t lo = static_cast<std::uint32_t>(memory::read(address, sizeof(lo), unprotect));
    std::uint32_t hi = static_cast<std::uint32_t>(memory::read(address + sizeof(lo), sizeof(hi), unprotect));
    std::uint64_t i = (static_cast<std::uint64_t>(hi) << 32) | lo;
    double d;
    std::memcpy(&d, &i, sizeof(d));
    return d;
  };

  m["setfloat"] = [](std::uintptr_t address, float value, std::optional<bool> unprotect) {
    std::int32_t i;
    std::memcpy(&i, &value, sizeof(i));
    memory::write(address, sizeof(i), i, unprotect);
    return true;
  };
  m["setdouble"] = [](std::uintptr_t address, double value, std::optional<bool> unprotect) {
    std::int32_t i[2];
    std::memcpy(&i, &value, sizeof(i));
    memory::write(address, sizeof(i[0]), i[0], unprotect);
    memory::write(address + sizeof(i[0]), sizeof(i[0]), i[1], unprotect);
    return true;
  };

  m["protect"] = [](std::uintptr_t address, std::size_t size, std::optional<int> new_protection) {
    memory::unprotect(address, size);
    return 0;
  };
  m["unprotect"] = [](std::uintptr_t address, std::size_t size, std::optional<int> new_protection) {
    memory::unprotect(address, size);
    return 0;
  };
  m["copy"] = [](std::uintptr_t dst, std::uintptr_t src, std::size_t size, std::optional<bool> unprotect) {
    memory::copy(dst, src, size, unprotect);
  };
  m["compare"] = [](std::uintptr_t a, std::uintptr_t b, std::size_t size, std::optional<bool> unprotect) {
    return memory::compare(a, b, size);
  };
  m["tostring"] = [](std::uintptr_t address, std::optional<std::size_t> size, std::optional<bool> unprotect) {
    auto* ptr = reinterpret_cast<const char*>(address);
    std::string s { ptr, size.has_value() ? *size : std::strlen(ptr) };
    return s;
  };
  m["tohex"] = [](std::uintptr_t address, std::size_t size, std::optional<bool> unprotect) {
    return strutils::hex_string(reinterpret_cast<void*>(address), size);
  };
  m["fill"] = [](std::uintptr_t address, int value, std::size_t size, std::optional<bool> unprotect) {
    memory::fill(address, value, size, unprotect);
  };
  m["strptr"] = [](const char* str) {
    return reinterpret_cast<std::uintptr_t>(str);
  };

  m["hex2bin"] = sol::overload(
      [](const char* hex) {
        return memory::hex_to_data(hex);
      },
      [](const char* hex, std::uintptr_t address, std::size_t size, std::optional<bool> unprotect) {
        memory::write_hex(hex, address, size, unprotect);
      });

  return m;
}