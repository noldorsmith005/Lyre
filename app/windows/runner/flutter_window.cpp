#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <gdiplus.h>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.lyre.app/icon",
      &flutter::StandardMethodCodec::GetInstance());

  HWND hwnd = GetHandle();
  channel->SetMethodCallHandler(
      [hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name().compare("setAppIcon") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto path_it = arguments->find(flutter::EncodableValue("path"));
            if (path_it != arguments->end()) {
              if (const auto* icon_path = std::get_if<std::string>(&path_it->second)) {
                int wchars_num = MultiByteToWideChar(CP_UTF8, 0, icon_path->c_str(), -1, NULL, 0);
                std::wstring wpath(wchars_num, 0);
                MultiByteToWideChar(CP_UTF8, 0, icon_path->c_str(), -1, &wpath[0], wchars_num);

                Gdiplus::GdiplusStartupInput gdiplusStartupInput;
                ULONG_PTR gdiplusToken;
                Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);
                Gdiplus::Bitmap bitmap(wpath.c_str());
                UINT width = bitmap.GetWidth();
                UINT height = bitmap.GetHeight();
                if (width > 0 && height > 0) {
                  Gdiplus::Color topCenterColor, leftCenterColor;
                  bitmap.GetPixel(width / 2, 0, &topCenterColor);
                  bitmap.GetPixel(0, height / 2, &leftCenterColor);

                  HICON hIcon = NULL;
                  if (topCenterColor.GetA() > 10 || leftCenterColor.GetA() > 10) {
                    float scale = 824.0f / 1024.0f;
                    float newW = width * scale;
                    float newH = height * scale;
                    float xOff = (width - newW) / 2.0f;
                    float yOff = (height - newH) / 2.0f;

                    Gdiplus::Bitmap paddedBitmap(width, height, PixelFormat32bppARGB);
                    Gdiplus::Graphics graphics(&paddedBitmap);
                    graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
                    graphics.DrawImage(&bitmap, xOff, yOff, newW, newH);
                    if (paddedBitmap.GetHICON(&hIcon) == Gdiplus::Ok && hIcon != NULL) {
                      SendMessage(hwnd, WM_SETICON, ICON_SMALL, (LPARAM)hIcon);
                      SendMessage(hwnd, WM_SETICON, ICON_BIG, (LPARAM)hIcon);
                      result->Success(flutter::EncodableValue(true));
                      Gdiplus::GdiplusShutdown(gdiplusToken);
                      return;
                    }
                  } else {
                    if (bitmap.GetHICON(&hIcon) == Gdiplus::Ok && hIcon != NULL) {
                      SendMessage(hwnd, WM_SETICON, ICON_SMALL, (LPARAM)hIcon);
                      SendMessage(hwnd, WM_SETICON, ICON_BIG, (LPARAM)hIcon);
                      result->Success(flutter::EncodableValue(true));
                      Gdiplus::GdiplusShutdown(gdiplusToken);
                      return;
                    }
                  }
                }
                Gdiplus::GdiplusShutdown(gdiplusToken);
              }
            }
          }
          result->Success(flutter::EncodableValue(false));
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
