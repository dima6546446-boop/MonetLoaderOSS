#pragma once
#include <sol/sol.hpp>
#include <imgui/imgui.h>

namespace lua::mimgui {

// Window Management
class ImGuiWindow {
public:
    bool Begin(const char* name, bool* p_open = nullptr, int flags = 0);
    void End();
    
    // Window properties
    bool IsWindowAppearing() const;
    bool IsWindowCollapsed() const;
    bool IsWindowFocused(int flags = 0) const;
    bool IsWindowHovered(int flags = 0) const;
    ImVec2 GetWindowPos() const;
    ImVec2 GetWindowSize() const;
    float GetWindowWidth() const;
    float GetWindowHeight() const;
    
    void SetWindowPos(const ImVec2& pos, int cond = 0);
    void SetWindowSize(const ImVec2& size, int cond = 0);
    void SetWindowCollapsed(bool collapsed, int cond = 0);
    void SetWindowFocus();
    
    // Window positioning
    void SetNextWindowPos(float x, float y, int cond = 0);
    void SetNextWindowSize(float w, float h, int cond = 0);
    void SetNextWindowCollapsed(bool collapsed, int cond = 0);
    void SetNextWindowContentSize(float w, float h);
};

// Drawing API
class ImGuiDraw {
public:
    void Text(const char* text);
    void TextColored(ImU32 col, const char* text);
    void TextDisabled(const char* text);
    void TextWrapped(const char* text);
    void TextUnformatted(const char* text);
    void LabelText(const char* label, const char* text);
    void BulletText(const char* text);
    void Bullet();
    void Separator();
    void NewLine();
    void Spacing();
    void Dummy(float w, float h);
    void Indent(float indent_w = 0);
    void Unindent(float indent_w = 0);
};

// Button API
class ImGuiButtons {
public:
    bool Button(const char* label, float w = 0, float h = 0);
    bool SmallButton(const char* label);
    bool InvisibleButton(const char* str_id, float w, float h);
    bool ArrowButton(const char* str_id, int dir);
    bool Checkbox(const char* label, bool* v);
    bool CheckboxFlags(const char* label, unsigned int* flags, unsigned int flags_value);
    bool RadioButton(const char* label, bool active);
    bool RadioButtonInt(const char* label, int* v, int v_button);
};

// Input API
class ImGuiInput {
public:
    bool InputText(const char* label, char* buf, size_t buf_size, int flags = 0);
    bool InputTextMultiline(const char* label, char* buf, size_t buf_size, float w = 0, float h = 0, int flags = 0);
    bool InputFloat(const char* label, float* v, float step = 0, float step_fast = 0, int decimal_precision = -1, int flags = 0);
    bool InputInt(const char* label, int* v, int step = 1, int step_fast = 100, int flags = 0);
    bool SliderFloat(const char* label, float* v, float v_min, float v_max, const char* format = "%.3f", int flags = 0);
    bool SliderInt(const char* label, int* v, int v_min, int v_max, const char* format = "%d", int flags = 0);
    bool ColorEdit4(const char* label, float* col, int flags = 0);
    bool ColorPicker4(const char* label, float* col, int flags = 0, const float* ref_col = nullptr);
};

// Selectable API
class ImGuiSelectable {
public:
    bool Selectable(const char* label, bool selected = false, int flags = 0, float w = 0, float h = 0);
    bool SelectableInt(const char* label, bool* p_selected, int flags = 0, float w = 0, float h = 0);
};

// Menu API
class ImGuiMenu {
public:
    bool BeginMenuBar();
    void EndMenuBar();
    bool BeginMainMenuBar();
    void EndMainMenuBar();
    bool BeginMenu(const char* label, bool enabled = true);
    void EndMenu();
    bool MenuItem(const char* label, const char* shortcut = nullptr, bool* p_selected = nullptr, bool enabled = true);
    bool MenuItemBool(const char* label, const char* shortcut, bool selected, bool enabled = true);
};

// Combo API
class ImGuiCombo {
public:
    bool BeginCombo(const char* label, const char* preview_value, int flags = 0);
    void EndCombo();
    bool Combo(const char* label, int* current_item, const char* const items[], int items_count, int popup_height = -1);
};

// List Box API
class ImGuiListBox {
public:
    bool BeginListBox(const char* label, float w = 0, float h = 0);
    void EndListBox();
    bool ListBox(const char* label, int* current_item, const char* const items[], int items_count, int height_in_items = -1);
};

// Columns API
class ImGuiColumns {
public:
    void Columns(int count = 1, const char* id = nullptr, bool border = true);
    void NextColumn();
    int GetColumnIndex() const;
    float GetColumnWidth(int column_index = -1) const;
    void SetColumnWidth(int column_index, float width);
    float GetColumnOffset(int column_index = -1) const;
    void SetColumnOffset(int column_index, float offset_x);
};

// Layout API
class ImGuiLayout {
public:
    void BeginGroup();
    void EndGroup();
    void SameLine(float offset_from_start_x = 0, float spacing = -1);
};

// Draw List API
class ImGuiDrawList {
public:
    void Line(float x1, float y1, float x2, float y2, ImU32 col, float thickness = 1);
    void Rect(float x1, float y1, float x2, float y2, ImU32 col, float rounding = 0, int flags = 0, float thickness = 1);
    void RectFilled(float x1, float y1, float x2, float y2, ImU32 col, float rounding = 0, int flags = 0);
    void Circle(float center_x, float center_y, float radius, ImU32 col, int num_segments = 0, float thickness = 1);
    void CircleFilled(float center_x, float center_y, float radius, ImU32 col, int num_segments = 0);
    void Polyline(const ImVec2* points, int num_points, ImU32 col, bool closed, float thickness);
    void ConvexPolyFilled(const ImVec2* points, int num_points, ImU32 col);
};

// Style API
class ImGuiStyle {
public:
    void PushStyleColor(int idx, ImU32 col);
    void PopStyleColor(int count = 1);
    void PushStyleVar(int idx, float val);
    void PushStyleVarImVec2(int idx, const ImVec2& val);
    void PopStyleVar(int count = 1);
    
    ImU32 GetColorU32(int idx, float alpha_mul = 1);
    ImU32 GetColorU32Vec4(const ImVec4& col);
    ImU32 GetColorU32U32(ImU32 col);
};

// Tooltip & Popup API
class ImGuiPopup {
public:
    void SetTooltip(const char* text);
    void BeginTooltip();
    void EndTooltip();
    
    bool BeginPopup(const char* str_id, int flags = 0);
    bool BeginPopupContextItem(const char* str_id = nullptr, int mouse_button = 1);
    bool BeginPopupContextWindow(const char* str_id = nullptr, int mouse_button = 1, bool also_over_items = true);
    bool BeginPopupContextVoid(const char* str_id = nullptr, int mouse_button = 1);
    bool BeginPopupModal(const char* name, bool* p_open = nullptr, int flags = 0);
    void EndPopup();
    void OpenPopup(const char* str_id);
    void CloseCurrentPopup();
    bool IsPopupOpen(const char* str_id);
    bool IsMousePosValid(const ImVec2* mouse_pos = nullptr);
};

// IO & Input API
class ImGuiIO_API {
public:
    bool IsKeyDown(int key);
    bool IsKeyPressed(int key, bool repeat = true);
    bool IsKeyReleased(int key);
    bool IsMouseDown(int button);
    bool IsMouseClicked(int button, bool repeat = false);
    bool IsMouseReleased(int button);
    bool IsMouseDoubleClicked(int button);
    bool IsMouseDragging(int button, float lock_threshold = -1);
    bool IsMouseHoveringRect(float r_min_x, float r_min_y, float r_max_x, float r_max_y, bool clip = true);
    
    ImVec2 GetMousePos();
    ImVec2 GetMousePosOnOpeningCurrentPopup();
    ImVec2 GetMouseDragDelta(int button = 0, float lock_threshold = -1);
    void ResetMouseDragDelta(int button = 0);
};

// Internal helper functions
namespace internal {
    void RegisterImGuiAPI(sol::state& state);
}

} // namespace lua::mimgui
