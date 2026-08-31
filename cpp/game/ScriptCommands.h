/*
  Plugin-SDK (Grand Theft Auto) SHARED header file
  Authors: GTA Community. See more here
  https://github.com/DK22Pac/plugin-sdk
  Do not delete this comment block. Respect others' work!
*/
#pragma once
#include "ScriptCommandNames.h"
#include <cstdint>
#include <cstring>
#include <vector>

enum eScriptParameterType {
  SCRIPTPARAM_END_OF_ARGUMENTS,
  SCRIPTPARAM_STATIC_INT_32BITS,
  SCRIPTPARAM_GLOBAL_NUMBER_VARIABLE,
  SCRIPTPARAM_LOCAL_NUMBER_VARIABLE,
  SCRIPTPARAM_STATIC_INT_8BITS,
  SCRIPTPARAM_STATIC_INT_16BITS,
  SCRIPTPARAM_STATIC_FLOAT,

  // Types below are only available in GTA SA

  // Number arrays
  SCRIPTPARAM_GLOBAL_NUMBER_ARRAY,
  SCRIPTPARAM_LOCAL_NUMBER_ARRAY,
  SCRIPTPARAM_STATIC_SHORT_STRING,
  SCRIPTPARAM_GLOBAL_SHORT_STRING_VARIABLE,
  SCRIPTPARAM_LOCAL_SHORT_STRING_VARIABLE,
  SCRIPTPARAM_GLOBAL_SHORT_STRING_ARRAY,
  SCRIPTPARAM_LOCAL_SHORT_STRING_ARRAY,
  SCRIPTPARAM_STATIC_PASCAL_STRING,
  SCRIPTPARAM_STATIC_LONG_STRING,
  SCRIPTPARAM_GLOBAL_LONG_STRING_VARIABLE,
  SCRIPTPARAM_LOCAL_LONG_STRING_VARIABLE,
  SCRIPTPARAM_GLOBAL_LONG_STRING_ARRAY,
  SCRIPTPARAM_LOCAL_LONG_STRING_ARRAY,
};

enum eButtonID {
  BUTTON_LEFT_STICK_X,
  BUTTON_LEFT_STICK_Y,
  BUTTON_RIGHT_STICK_X,
  BUTTON_RIGHT_STICK_Y,
  BUTTON_LEFT_SHOULDER1,
  BUTTON_LEFT_SHOULDER2,
  BUTTON_RIGHT_SHOULDER1,
  BUTTON_RIGHT_SHOULDER2,
  BUTTON_DPAD_UP,
  BUTTON_DPAD_DOWN,
  BUTTON_DPAD_LEFT,
  BUTTON_DPAD_RIGHT,
  BUTTON_START,
  BUTTON_SELECT,
  BUTTON_SQUARE,
  BUTTON_TRIANGLE,
  BUTTON_CROSS,
  BUTTON_CIRCLE,
  BUTTON_LEFTSHOCK,
  BUTTON_RIGHTSHOCK,
};

union tScriptParam {
  std::uint32_t uParam;
  std::int32_t iParam;
  float fParam;
};

#include "gta_struct.inl"
class CRunningScript {
  public:
  enum { NUM_LVARS = 42 };

  CRunningScript* m_pNext;
  CRunningScript* m_pPrev;
  char m_szName[8];
  std::uint8_t* m_pBaseIP;
  std::uint8_t* m_pCurrentIP;
  std::uint8_t* m_apStack[8];
  std::uint16_t m_nSP;
  tScriptParam m_aLocalVars[NUM_LVARS];
  bool m_bIsActive;
  bool m_bCondResult;
  bool m_bUseMissionCleanup;
  bool m_bIsExternal;
  bool m_bTextBlockOverride;
  std::int8_t m_nScriptBrainType;
  std::uint32_t m_nWakeTime;
  std::uint16_t m_nLogicalOp;
  bool m_bNotFlag;
  bool m_bWastedBustedCheck;
  bool m_bWastedOrBusted;
  std::int32_t m_pSceneSkipIP;
  bool m_bIsMission;

  public:
  void ProcessOneCommand()
  {
    return GTA_FUNC_AT_THIS(void, lib_manager::process_one_command)(this);
  }
};
#include "gta_struct.inl"

// struct CPed;
// struct CVehicle;
// class CObject;

namespace game {

class scripting {

  public:
  enum ScriptCommandEndParameter {
    END_PARAMETER
  };

  private:
  enum ScriptResultVarType {
    SCRIPT_RESULT_VAR_NUMBER,
    SCRIPT_RESULT_VAR_STRING,
    SCRIPT_RESULT_VAR_PED,
    SCRIPT_RESULT_VAR_VEHICLE,
    SCRIPT_RESULT_VAR_OBJECT
  };

  class ScriptCode {
    unsigned char* data;
    unsigned int capacity;
    unsigned int size;
    bool allocated;

    struct VarToSet {
      unsigned int varIndex;
      void* pVar;
      ScriptResultVarType varType;

			VarToSet() = default;
      VarToSet(unsigned int _varIndex, void* _pVar, ScriptResultVarType _varType);
    };
    VarToSet varsToSet[CRunningScript::NUM_LVARS];
    int varsToSetIndex;
    unsigned short varIndexCounter;

    unsigned char dataBuffer[256];

public:
    ScriptCode(short commandId = -1);
    ~ScriptCode();
    void AddParameterDescription(unsigned char paramType);
    void AddBytes(unsigned char* bytes, unsigned int count);
    unsigned char* GetData();
    void SaveResultVariables(CRunningScript* script);
    void operator<<(char n);
    void operator<<(unsigned char n);
    void operator<<(short n);
    void operator<<(unsigned short n);
    void operator<<(int n);
    void operator<<(unsigned int n);
    void operator<<(float n);
    void operator<<(double n);
    void operator<<(ScriptCommandEndParameter);
    void operator<<(char* str);
    void operator<<(const char* str);
    void operator<<(float* p);
    void operator<<(int* p);
    void operator<<(unsigned int* p);
    void operator<<(char (*p)[16]);
    // void operator<<(CPed* n);
    // void operator<<(CVehicle* n);
    // void operator<<(CObject* n);
    // void operator<<(CPed** p);
    // void operator<<(CVehicle** p);
    // void operator<<(CObject** p);

    template <typename T>
    void Pack(T value)
    {
      operator<<(value);
    }

    template <typename First, typename... Rest>
    void Pack(First firstValue, Rest... rest)
    {
      Pack(firstValue);
      Pack(rest...);
    }

    void Pack() { }
  };

  static void SafeProcessOneCommand(CRunningScript& script, unsigned int commandId);

  public:
  static void InitSafeProcessing();

  template <typename... ArgTypes>
  static bool CallCommandById(unsigned int commandId, ArgTypes... arguments)
  {
    // create our 'script' object
    static CRunningScript script;
    memset(&script, 0, sizeof(CRunningScript));
    script.m_bNotFlag = (commandId >> 15) & 1;
    // our script code
    ScriptCode code(static_cast<short>(commandId));
    // for all arguments: add them to script code
    code.Pack(arguments...);
    script.m_pBaseIP = script.m_pCurrentIP = code.GetData();
    SafeProcessOneCommand(script, commandId);
    code.SaveResultVariables(&script);
    return script.m_bCondResult ? true : false;
  }

  template <typename... ArgTypes>
  static bool CallCommandById(game::Commands commandId, ArgTypes... arguments)
  {
    return CallCommandById(static_cast<unsigned int>(commandId) - 0x10000, arguments...);
  }
};

template <game::Commands CommandId, typename... ArgTypes>
bool Command(ArgTypes... arguments)
{
  return scripting::CallCommandById(static_cast<unsigned int>(CommandId) - 0x10000, arguments...);
}

template <int CommandId, typename... ArgTypes>
bool Command(ArgTypes... arguments)
{
  return scripting::CallCommandById(CommandId, arguments...);
}

};