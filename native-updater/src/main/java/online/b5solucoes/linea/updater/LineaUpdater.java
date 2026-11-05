package online.b5solucoes.linea.updater;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;

/** Hands one verified game APK to Android; never silently installs packages. */
public final class LineaUpdater extends GodotPlugin {
    public LineaUpdater(Godot godot) { super(godot); }

    @NonNull @Override public String getPluginName() { return "LineaUpdater"; }

    @UsedByGodot
    public int installApk(String path) {
        final Activity activity = getActivity();
        if (activity == null) return -1;
        try {
            File source = new File(path).getCanonicalFile();
            String privateRoot = activity.getFilesDir().getCanonicalPath() + File.separator;
            if (!source.getPath().startsWith(privateRoot) || !source.getName().equals("TheLastLinea.apk")
                    || !source.isFile() || source.length() < 100000 || source.length() > 262144000) return -2;

            PackageManager pm = activity.getPackageManager();
            PackageInfo candidate = pm.getPackageArchiveInfo(source.getPath(), 0);
            PackageInfo installed = pm.getPackageInfo(activity.getPackageName(), 0);
            if (candidate == null || !activity.getPackageName().equals(candidate.packageName)) return -3;
            long next = Build.VERSION.SDK_INT >= 28 ? candidate.getLongVersionCode() : candidate.versionCode;
            long current = Build.VERSION.SDK_INT >= 28 ? installed.getLongVersionCode() : installed.versionCode;
            if (next <= current) return -4;

            if (Build.VERSION.SDK_INT >= 26 && !pm.canRequestPackageInstalls()) {
                activity.runOnUiThread(() -> activity.startActivity(new Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:" + activity.getPackageName()))));
                return 1;
            }

            File directory = new File(activity.getCacheDir(), "linea-updates");
            if (!directory.isDirectory() && !directory.mkdirs()) return -5;
            File target = new File(directory, "TheLastLinea.apk");
            try (FileInputStream input = new FileInputStream(source);
                 FileOutputStream output = new FileOutputStream(target)) {
                byte[] buffer = new byte[65536];
                int count;
                while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
                output.getFD().sync();
            }
            Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName()+".linea.updates", target);
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(uri, "application/vnd.android.package-archive");
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            activity.runOnUiThread(() -> activity.startActivity(intent));
            return 0;
        } catch (Exception error) {
            android.util.Log.e("LineaUpdater", "Could not prepare update", error);
            return -6;
        }
    }
}
