package online.b5solucoes.linea.updater;

/** A distinct provider avoids manifest merging with Godot's own FileProvider. */
public final class LineaUpdateProvider extends androidx.core.content.FileProvider {
    public LineaUpdateProvider() { super(); }
}
