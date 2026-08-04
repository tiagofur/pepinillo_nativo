namespace Pepinillo.Core.Utilities;

/// <summary>
/// Pure placement math for the Compact Overlay mini-timer (W14 multi-monitor).
/// WinUI host supplies work-area rectangles from DisplayArea; this type clamps off-screen positions.
/// </summary>
public static class MiniTimerPlacement
{
    public const int DefaultWidth = 320;
    public const int DefaultHeight = 120;
    public const int MinWidth = 160;
    public const int MinHeight = 80;
    public const int MaxWidth = 640;
    public const int MaxHeight = 320;

    public readonly record struct Rect(int X, int Y, int Width, int Height);

    public readonly record struct WorkArea(int X, int Y, int Width, int Height);

    /// <summary>
    /// Builds a window rect from persisted nullable bounds, applying defaults and size clamps.
    /// Returns null when X/Y were never saved (caller should leave system default placement).
    /// </summary>
    public static Rect? FromPersisted(int? x, int? y, int? width, int? height)
    {
        if (x is null || y is null)
            return null;

        var w = NormalizeWidth(width);
        var h = NormalizeHeight(height);
        return new Rect(x.Value, y.Value, w, h);
    }

    public static int NormalizeWidth(int? width)
    {
        var w = width ?? DefaultWidth;
        if (w < MinWidth) return MinWidth;
        if (w > MaxWidth) return MaxWidth;
        return w;
    }

    public static int NormalizeHeight(int? height)
    {
        var h = height ?? DefaultHeight;
        if (h < MinHeight) return MinHeight;
        if (h > MaxHeight) return MaxHeight;
        return h;
    }

    /// <summary>
    /// True when at least a quarter of the window intersects the work area (visible enough).
    /// </summary>
    public static bool IsReasonablyOnScreen(Rect window, WorkArea work)
    {
        if (work.Width <= 0 || work.Height <= 0 || window.Width <= 0 || window.Height <= 0)
            return false;

        var intersectW = OverlapLength(window.X, window.Width, work.X, work.Width);
        var intersectH = OverlapLength(window.Y, window.Height, work.Y, work.Height);
        if (intersectW <= 0 || intersectH <= 0)
            return false;

        var windowArea = (long)window.Width * window.Height;
        var intersectArea = (long)intersectW * intersectH;
        return intersectArea * 4 >= windowArea;
    }

    /// <summary>
    /// Clamps the window so it fully fits inside the work area when possible; otherwise pins top-left.
    /// </summary>
    public static Rect ClampToWorkArea(Rect window, WorkArea work)
    {
        if (work.Width <= 0 || work.Height <= 0)
            return window;

        var w = window.Width > 0 ? window.Width : DefaultWidth;
        var h = window.Height > 0 ? window.Height : DefaultHeight;

        // If larger than work area, shrink to fit.
        if (w > work.Width) w = work.Width;
        if (h > work.Height) h = work.Height;

        var x = window.X;
        var y = window.Y;

        if (x < work.X)
            x = work.X;
        if (y < work.Y)
            y = work.Y;
        if (x + w > work.X + work.Width)
            x = work.X + work.Width - w;
        if (y + h > work.Y + work.Height)
            y = work.Y + work.Height - h;

        return new Rect(x, y, w, h);
    }

    /// <summary>
    /// If the window is not reasonably on the given work area, clamp it; otherwise return as-is.
    /// </summary>
    public static Rect EnsureVisible(Rect window, WorkArea work)
    {
        if (IsReasonablyOnScreen(window, work))
            return new Rect(window.X, window.Y, NormalizeWidth(window.Width), NormalizeHeight(window.Height));

        return ClampToWorkArea(
            new Rect(window.X, window.Y, NormalizeWidth(window.Width), NormalizeHeight(window.Height)),
            work);
    }

    private static int OverlapLength(int start, int length, int otherStart, int otherLength)
    {
        var a0 = start;
        var a1 = start + length;
        var b0 = otherStart;
        var b1 = otherStart + otherLength;
        var left = a0 > b0 ? a0 : b0;
        var right = a1 < b1 ? a1 : b1;
        return right > left ? right - left : 0;
    }
}
