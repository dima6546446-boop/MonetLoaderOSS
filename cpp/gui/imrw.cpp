#include "imrw.h"
#include "game/CRect.h"
#include "game/RenderWare.h"
#include "imgui/imgui.h"
#include "lib_manager.h"
#include "stb_image.h"
#include <cstddef>
#include <cstdlib>
#include <ctime>
#include <sys/time.h>

namespace {
struct imrw_data {
  rw::RwIm2DVertex* vb { nullptr };
  std::size_t vb_size { 2048 };
  double time { 0.f };
};

void set_scissor_rect(CRect& rect)
{
  return ((void (*)(CRect&))lib_manager::set_scissor)(rect);
}

imrw::image_data create_image_from_rgba8888(stbi_uc* pxs, int iw, int ih, bool is_stb_image = true)
{
  rw::RwRaster* raster = rw::RwRasterCreate(iw, ih, 32,
      static_cast<std::int32_t>(rw::rwRASTERFORMAT8888) | rw::rwRASTERTYPETEXTURE);
  if (!raster) {
    if (is_stb_image) {
      stbi_image_free(pxs);
    }
    return { nullptr, 0, 0 };
  }

  rw::RwRasterLock(raster, 0, rw::rwRASTERLOCKWRITE | rw::rwRASTERLOCKNOFETCH);
  if (!raster->cpPixels) {
    raster->cpPixels = static_cast<std::uint8_t*>(std::malloc(static_cast<std::size_t>(4) * raster->width * raster->height));
    raster->stride = 4 * raster->width;
  }

  std::uint8_t* raster_pxs = raster->cpPixels;
  stbi_uc* pxs_read = pxs;
  for (int i = 0; i < raster->height; ++i) {
    std::size_t read = static_cast<std::size_t>(4) * raster->width;
    memcpy(raster_pxs, pxs_read, read);
    raster_pxs += raster->stride;
    pxs_read += read;
  }

  rw::RwRasterUnlock(raster);

  if (is_stb_image) {
    stbi_image_free(pxs);
  }
  return { raster, static_cast<float>(iw), static_cast<float>(ih) };
}

void do_render(ImDrawData* draw_data)
{
  const rw::RwReal recipNearClip = *(rw::RwReal*)(lib_manager::recip_near_clip); // CSprite2d::RecipNearClip
  const rw::RwReal nearScreenZ = rw::RwIm2DGetNearScreenZ();
  auto* r = (imrw_data*)ImGui::GetIO().BackendRendererUserData;

  if (!r->vb || r->vb_size < draw_data->TotalVtxCount) {
    if (r->vb) {
      delete[] r->vb;
    }
    r->vb_size = draw_data->TotalVtxCount;
    r->vb = new rw::RwIm2DVertex[r->vb_size];
  }

  rw::RwIm2DVertex* vtx_dst = r->vb;
  int vtx_offset = 0;

  for (int n = 0; n < draw_data->CmdListsCount; n++) {
    const ImDrawList* cmd_list = draw_data->CmdLists[n];
    const ImDrawVert* vtx_src = cmd_list->VtxBuffer.Data;

    for (int i = 0; i < cmd_list->VtxBuffer.Size; i++) {
      RwIm2DVertexSetScreenX(vtx_dst, vtx_src->pos.x);
      RwIm2DVertexSetScreenY(vtx_dst, vtx_src->pos.y);
      RwIm2DVertexSetScreenZ(vtx_dst, nearScreenZ);
      RwIm2DVertexSetRecipCameraZ(vtx_dst, recipNearClip);
      vtx_dst->emissiveColor = vtx_src->col;
      RwIm2DVertexSetU(vtx_dst, vtx_src->uv.x);
      RwIm2DVertexSetV(vtx_dst, vtx_src->uv.y);

      vtx_dst++;
      vtx_src++;
    }

    const ImDrawIdx* idx_buffer = cmd_list->IdxBuffer.Data;
    for (int cmd_i = 0; cmd_i < cmd_list->CmdBuffer.Size; cmd_i++) {
      const ImDrawCmd* pcmd = &cmd_list->CmdBuffer[cmd_i];

      if (pcmd->UserCallback) {
        pcmd->UserCallback(cmd_list, pcmd);
      } else {
        CRect rect;
        rect.left = pcmd->ClipRect.x;
        rect.bottom = pcmd->ClipRect.w;
        rect.right = pcmd->ClipRect.z;
        rect.top = pcmd->ClipRect.y;
        set_scissor_rect(rect);

        rw::RwRenderStateSet(rw::rwRENDERSTATETEXTURERASTER, (void*)pcmd->TextureId);
        rw::RwIm2DRenderIndexedPrimitive(rw::rwPRIMTYPETRILIST,
            &r->vb[vtx_offset + pcmd->VtxOffset], (std::int32_t)(cmd_list->VtxBuffer.Size - pcmd->VtxOffset),
            (rw::RwImVertexIndex*)idx_buffer + pcmd->IdxOffset, static_cast<std::int32_t>(pcmd->ElemCount));
      }
    }
    vtx_offset += cmd_list->VtxBuffer.Size;
  }

  CRect rect;
  rect.left = 0.f;
  rect.bottom = 0.f;
  rect.right = 0.f;
  rect.top = 0.f;
  set_scissor_rect(rect);
}
}

void imrw::init()
{
  ImGuiIO& io = ImGui::GetIO();

  io.BackendRendererName = "RW";
  io.BackendRendererUserData = IM_NEW(imrw_data) {};
  io.BackendFlags |= ImGuiBackendFlags_RendererHasVtxOffset;
  io.DisplaySize = { static_cast<float>(rw::RsGlobal()->screenWidth), static_cast<float>(rw::RsGlobal()->screenHeight) };
}

void imrw::render_draw_data(ImDrawData* draw_data)
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wint-to-void-pointer-cast"
  int vertexAlpha;
  rw::RwRenderStateGet(rw::rwRENDERSTATEVERTEXALPHAENABLE, &vertexAlpha);
  int srcBlend;
  rw::RwRenderStateGet(rw::rwRENDERSTATESRCBLEND, &srcBlend);
  int dstBlend;
  rw::RwRenderStateGet(rw::rwRENDERSTATEDESTBLEND, &dstBlend);
  int ztest;
  rw::RwRenderStateGet(rw::rwRENDERSTATEZTESTENABLE, &ztest);
  int zwrite;
  rw::RwRenderStateGet(rw::rwRENDERSTATEZWRITEENABLE, &zwrite);
  void* tex;
  rw::RwRenderStateGet(rw::rwRENDERSTATETEXTURERASTER, &tex);
  int addr;
  rw::RwRenderStateGet(rw::rwRENDERSTATETEXTUREADDRESS, &addr);
  int addrU;
  rw::RwRenderStateGet(rw::rwRENDERSTATETEXTUREADDRESSU, &addrU);
  int addrV;
  rw::RwRenderStateGet(rw::rwRENDERSTATETEXTUREADDRESSV, &addrV);
  int filter;
  rw::RwRenderStateGet(rw::rwRENDERSTATETEXTUREFILTER, &filter);
  int perspective;
  rw::RwRenderStateGet(rw::rwRENDERSTATETEXTUREPERSPECTIVE, &perspective);
  int cullmode;
  rw::RwRenderStateGet(rw::rwRENDERSTATECULLMODE, &cullmode);
  int fog;
  rw::RwRenderStateGet(rw::rwRENDERSTATEFOGENABLE, &fog);
  std::uint32_t borderColor;
  rw::RwRenderStateGet(rw::rwRENDERSTATEBORDERCOLOR, &borderColor);
  int alphaFunc;
  rw::RwRenderStateGet(rw::rwRENDERSTATEALPHATESTFUNCTION, &alphaFunc);
  int alphaFuncRef;
  rw::RwRenderStateGet(rw::rwRENDERSTATEALPHATESTFUNCTIONREF, &alphaFuncRef);
  int shademode;
  rw::RwRenderStateGet(rw::rwRENDERSTATESHADEMODE, &shademode);

  rw::RwRenderStateSet(rw::rwRENDERSTATEVERTEXALPHAENABLE, (void*)true);
  rw::RwRenderStateSet(rw::rwRENDERSTATESRCBLEND, (void*)rw::rwBLENDSRCALPHA);
  rw::RwRenderStateSet(rw::rwRENDERSTATEDESTBLEND, (void*)rw::rwBLENDINVSRCALPHA);
  rw::RwRenderStateSet(rw::rwRENDERSTATEZTESTENABLE, (void*)false);
  rw::RwRenderStateSet(rw::rwRENDERSTATEZWRITEENABLE, (void*)true);
  rw::RwRenderStateSet(rw::rwRENDERSTATETEXTUREADDRESS, (void*)rw::rwTEXTUREADDRESSCLAMP);
  rw::RwRenderStateSet(rw::rwRENDERSTATETEXTUREADDRESSU, (void*)rw::rwTEXTUREADDRESSCLAMP);
  rw::RwRenderStateSet(rw::rwRENDERSTATETEXTUREADDRESSV, (void*)rw::rwTEXTUREADDRESSCLAMP);
  rw::RwRenderStateSet(rw::rwRENDERSTATETEXTUREFILTER, (void*)rw::rwFILTERLINEAR);
  rw::RwRenderStateSet(rw::rwRENDERSTATETEXTUREPERSPECTIVE, (void*)false);
  rw::RwRenderStateSet(rw::rwRENDERSTATECULLMODE, (void*)rw::rwCULLMODECULLNONE);
  rw::RwRenderStateSet(rw::rwRENDERSTATEFOGENABLE, (void*)false);
  rw::RwRenderStateSet(rw::rwRENDERSTATEBORDERCOLOR, (void*)0);
  rw::RwRenderStateSet(rw::rwRENDERSTATEALPHATESTFUNCTION, (void*)rw::rwALPHATESTFUNCTIONGREATER);
  rw::RwRenderStateSet(rw::rwRENDERSTATEALPHATESTFUNCTIONREF, (void*)2);
  rw::RwRenderStateSet(rw::rwRENDERSTATESHADEMODE, (void*)rw::rwSHADEMODEFLAT);

  do_render(draw_data);

  rw::RwRenderStateSet(rw::rwRENDERSTATEVERTEXALPHAENABLE, (void*)vertexAlpha);
  rw::RwRenderStateSet(rw::rwRENDERSTATESRCBLEND, (void*)srcBlend);
  rw::RwRenderStateSet(rw::rwRENDERSTATEDESTBLEND, (void*)dstBlend);
  rw::RwRenderStateSet(rw::rwRENDERSTATEZTESTENABLE, (void*)ztest);
  rw::RwRenderStateSet(rw::rwRENDERSTATEZWRITEENABLE, (void*)zwrite);
  rw::RwRenderStateSet(rw::rwRENDERSTATETEXTURERASTER, tex);
  rw::RwRenderStateSet(rw::rwRENDERSTATETEXTUREADDRESS, (void*)addr);
  rw::RwRenderStateSet(rw::rwRENDERSTATETEXTUREADDRESSU, (void*)addrU);
  rw::RwRenderStateSet(rw::rwRENDERSTATETEXTUREADDRESSV, (void*)addrV);
  rw::RwRenderStateSet(rw::rwRENDERSTATETEXTUREFILTER, (void*)filter);
  rw::RwRenderStateSet(rw::rwRENDERSTATETEXTUREPERSPECTIVE, (void*)perspective);
  rw::RwRenderStateSet(rw::rwRENDERSTATECULLMODE, (void*)cullmode);
  rw::RwRenderStateSet(rw::rwRENDERSTATEFOGENABLE, (void*)fog);
  rw::RwRenderStateSet(rw::rwRENDERSTATEBORDERCOLOR, (void*)borderColor);
  rw::RwRenderStateSet(rw::rwRENDERSTATEALPHATESTFUNCTION, (void*)alphaFunc);
  rw::RwRenderStateSet(rw::rwRENDERSTATEALPHATESTFUNCTIONREF, (void*)alphaFuncRef);
  rw::RwRenderStateSet(rw::rwRENDERSTATESHADEMODE, (void*)shademode);
#pragma clang diagnostic pop
}

void imrw::create_font()
{
  destroy_font();
  ImGuiIO& io = ImGui::GetIO();

  // Build texture atlas
  unsigned char* pxs;
  int width, height, bytes_per_pixel;
  io.Fonts->GetTexDataAsRGBA32(&pxs, &width, &height, &bytes_per_pixel);
  io.Fonts->TexID = create_image_from_rgba8888(pxs, width, height, false).raster;
  io.Fonts->ClearTexData();
}

void imrw::destroy_font()
{
  // Destroy raster
  ImGuiIO& io = ImGui::GetIO();
  if (io.Fonts->TexID) {
    destroy_image(io.Fonts->TexID);
    io.Fonts->TexID = nullptr;
  }
}

void imrw::shutdown()
{
  destroy_font();
  auto* r = (imrw_data*)ImGui::GetIO().BackendRendererUserData;

  // Destroy vertex buffer
  if (r->vb) {
    delete[] r->vb;
    r->vb = nullptr;
  }

  IM_DELETE(r);
  return;
}

void imrw::new_frame()
{
  ImGuiIO& io = ImGui::GetIO();
  if (!io.Fonts->TexID)
    create_font();
  io.DisplaySize = { static_cast<float>(rw::RsGlobal()->screenWidth), static_cast<float>(rw::RsGlobal()->screenHeight) };
  auto* r = (imrw_data*)io.BackendRendererUserData;

  struct timespec current_timespec;
  clock_gettime(CLOCK_MONOTONIC, &current_timespec);
  double current_time = (double)(current_timespec.tv_sec) + (current_timespec.tv_nsec / 1000000000.0);
  io.DeltaTime = r->time > 0.0 ? (float)(current_time - r->time) : 0.f;
  r->time = current_time;
}

imrw::image_data imrw::load_image(const char* file)
{
  // rw::RwImage* image = rw::RtPNGImageRead(path);
  // if (!image) {
  //   return { nullptr, 0.f, 0.f };
  // }

  // std::int32_t w, h, d, flags;
  // rw::RwImageFindRasterFormat(image, rw::rwRASTERTYPETEXTURE, &w, &h, &d, &flags);
  // rw::RwRaster* raster = rw::RwRasterCreate(image->width, image->height, d, flags);
  // if (!raster) {
  //   rw::RwImageDestroy(image);
  //   return { nullptr, 0.f, 0.f };
  // }

  // raster = rw::RwRasterSetFromImage(raster, image);
  // rw::RwImageDestroy(image);

  int iw, ih, in;
  stbi_uc* pxs = stbi_load(file, &iw, &ih, &in, 4);
  if (!pxs) {
    return { nullptr, 0, 0 };
  }

  return create_image_from_rgba8888(pxs, iw, ih);
}

imrw::image_data imrw::load_image_from_memory(const unsigned char* data, int length)
{
  int iw, ih, in;
  stbi_uc* pxs = stbi_load_from_memory(data, length, &iw, &ih, &in, 4);
  if (!pxs) {
    return { nullptr, 0, 0 };
  }

  return create_image_from_rgba8888(pxs, iw, ih);
}

imrw::image_data imrw::get_image_data(ImTextureID raster_)
{
  if (!raster_) {
    return { nullptr, 0, 0 };
  }

  auto* raster = static_cast<rw::RwRaster*>(raster_);
  return { raster, static_cast<float>(raster->width), static_cast<float>(raster->height) };
}

void imrw::destroy_image(ImTextureID raster)
{
  if (!raster) {
    return;
  }

  rw::RwRasterDestroy(static_cast<rw::RwRaster*>(raster));
}