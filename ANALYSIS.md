# RoMidi Script — Full Deobfuscation Analysis

## Entry Point
```lua
loadstring(game:HttpGet("https://romidi-script.pages.dev/RoMidi.txt"))()
```

## Obfuscation Layers

The script uses **ClydeProtection v2** — a Lua VM-based obfuscator. Two nested layers of ClydeProtection wrap a plaintext key-system loader.

---

### Layer 1: `RoMidi.txt` (ClydeProtection v2)
- **Size**: ~34 KB
- **Protection**: Base85 encoding → XOR with S-box + key tables → Adler32 checksum verification
- **Inner VM**: Custom Lua VM with state-machine dispatch, encrypted string table (W), bytecode (X), and 199 encrypted API imports
- **Decrypted behavior**:
```lua
loadstring(game:HttpGet("https://gist.githubusercontent.com/wownskdo/c5e1091bbaf534da3f4da608af00a98d/raw/RoMidiYessirAp"))()
```

### Layer 2: `RoMidiYessirAp` (ClydeProtection v2)
- **Size**: ~34 KB
- **Protection**: Same ClydeProtection v2 with different encryption parameters
- **Inner VM**: Different XOR keys (70 + i*29), pipeline: _P→_Q→_R→_S→_T→_U→_V
- **Decrypted behavior**:
```lua
loadstring(game:HttpGet("https://gist.githubusercontent.com/wownskdo/2702d7700c9eafc0e9b4a4b192ba3913/raw/yes"))()
```

### Layer 3: `yes` — Key System (Plaintext)
- **Size**: ~31 KB
- **No obfuscation** — clean Lua source
- **Purpose**: RoMidi Key System with GUI
- **Key validation URL**: `https://gist.githubusercontent.com/VBfHKC86WxpXyIgr/6ae3fa80ba16318c88b4c2cb9485bb39/raw/key.json`
- **Key page**: `https://pandahub-romidi.vercel.app/getkey.html`
- **Key format**: `ROMIDI-XXXX-XXXX`
- **Key TTL**: 24 hours (saved to `.RoMidi/.key` and `.RoMidi/.keytime`)
- **Accepts**: current key (`keyNow`) OR previous day's key (`keyYesterday`)
- **On valid key**: Loads the actual script from `mainscript` URL

### Layer 4: `GUIChoose.lua` — Launcher (Plaintext)
- **URL**: `https://gist.githubusercontent.com/VBfHKC86WxpXyIgr/db6cddfb66e46757fe1be3f67e8342e0/raw/GUIChoose.lua`
- **Purpose**: GUI to choose between Full UI or Compact UI
- **Full UI**: `https://gist.githubusercontent.com/VBfHKC86WxpXyIgr/fc61c54dec8188ca691791a09c7effae/raw/RoMidiFull.lua`
- **Compact UI**: `https://gist.githubusercontent.com/VBfHKC86WxpXyIgr/fb509ff6676f405c21992fba67e48b78/raw/Compact.lua`

---

## Complete Call Chain

```
User runs loadstring(game:HttpGet("https://romidi-script.pages.dev/RoMidi.txt"))()
  ↓ ClydeProtection v2 layer 1 decrypts to:
  loadstring(game:HttpGet(".../RoMidiYessirAp"))()
    ↓ ClydeProtection v2 layer 2 decrypts to:
    loadstring(game:HttpGet(".../yes"))()
      ↓ Key System GUI (plaintext):
        - Shows key input dialog
        - Validates against key.json gist
        - On success, loads GUIChoose.lua
          ↓ Launcher GUI (plaintext):
            - Choose "Full UI" or "Compact UI"
            - Loads RoMidiFull.lua or Compact.lua
```

## ClydeProtection v2 — Technical Details

### Encryption Pipeline
1. **Base85 decode** — custom alphabet starting at ASCII 33
2. **Integrity check** — XOR sum of key stream, S-box sum % 65536
3. **S-box construction** — 256-byte table: `S[i] = source[i] XOR constant`
4. **Key construction** — variable-length table: `K[i] = source[i] XOR constant`
5. **XOR decrypt** — data bytes XORed with key table (cycling)
6. **Adler32 verify** — checksum of decrypted output

### Inner VM String Table Decryption (6-stage pipeline)
1. **_P**: Convert Lua strings to byte arrays
2. **_Q**: XOR with precomputed _Y lookup table + position offset
3. **_R**: Alternating XOR — odd positions use one formula, even positions another
4. **_S**: Chain cipher with feedback: `byte[j] ^= (byte[j-1] * 123 + constant + offset) & 0xFF`
5. **_T**: Subtract rolling key: `byte[j] -= (base + offset + j * multiplier) & 0xFF`
6. **_U**: S-box substitution with inverse lookup table, then XOR with position
7. **_V**: Convert byte arrays back to strings

### Inner VM Bytecode
- 4 values per instruction: `[opcode, T, U, V]`
- Opcode encrypted with position-dependent formula: `_J = k[m] XOR (115 + m*29 + m²*112) & 0xFF XOR state`
- State updated after each instruction for chained encryption
- Opcodes include: NOP(0), JMP(1), RETURN(7), SELF(25), GETGLOBAL(33), INTEGRITY(41), LOADK(47), CALL(53)

### API Import Tables
- ~200 Roblox API functions imported through encrypted name tables (_k, _h, _n, _q)
- Each name XORed with `(base + i * multiplier) & 0xFF` per character
- Layer 1 uses `(142 + i*142) & 0xFF`, Layer 2 uses `(70 + i*29) & 0xFF`
