# Android GL surface recovery

`GLSurfaceView.java` comes from the official Godot 4.6.3 source:
https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/java/lib/src/main/java/org/godotengine/godot/gl/GLSurfaceView.java

The source retains its AOSP Apache-2.0 license notice. Original file SHA-256:
15d56bda1cf68e72bb3b48f8e2b0cd6a57dfab9832a674a6f2b4ce82b2f44dbb

The local change recovers one `EGL_BAD_SURFACE` race per resume/surface event by rebuilding the EGL window surface while retaining the GL context. Native surface callbacks also clear a stale bad-surface flag. Permanent errors do not spin indefinitely. `tools/patch_android_gl.py` compiles this class and replaces only its class family in the release AAR during Actions. Native Godot libraries remain official and unchanged.

The full Apache-2.0 notice is included in [licenses/android-surface.txt](../licenses/android-surface.txt) and the in-game license screen.
