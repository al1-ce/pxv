module modules.color;

import std.regex: regex, matchAll;
import std.conv: to;
import std.math: floor;
import std.algorithm: canFind, startsWith, find, countUntil, clamp, max, min;

class Color {
    alias fClamp = (T, M, A) => clamp(to!float(T), to!float(M), to!float(A));

    float r;
    float g;
    float b;
    float a;

    alias BLACK = () => new Color(0, 0, 0, 1f);
    alias WHITE = () => new Color(1f, 1f, 1f, 1f);
    alias RED = () => new Color(1.0, 0, 0, 1.0);
    alias GREEN = () => new Color(0, 1f, 0, 1f);
    alias BLUE = () => new Color(0, 0, 1f, 1f);
    alias TRANSPARENT = () => new Color(0, 0, 0, 0);

    static const string[] LOWRGB = [
    "#000000", "#800000", "#008000", "#808000", "#000080", "#800080", "#008080", "#c0c0c0",
    "#808080", "#ff0000", "#00ff00", "#ffff00", "#0000ff", "#ff00ff", "#00ffff", "#ffffff"
    ];

    this() {
        this(0, 0, 0, 0);
    }

    this(float r, float g, float b, float a = 1) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }

    this(int r, int g, int b, int a) {
        this.r = to!float(r / 255f);
        this.g = to!float(g / 255f);
        this.b = to!float(b / 255f);
        this.b = to!float(b / 255f);
    }

    this(int r, int g, int b) {
        this(r, g, b, 255);
    }

    static Color getFromAnsi8(int ansi, bool isBackground) {
        // TODO
        // probably just get from array
        return new Color(0, 0, 0);
    }

    static Color getFromAnsi(int ansi) {
        if (ansi < 0 || ansi > 255) return new Color(0, 0, 0);
        if (ansi < 16) return Color.getFromHex(Color.LOWRGB[ansi]);

        if (ansi > 231) {
            const int s = (ansi - 232) * 10 + 8;
            return new Color(s, s, s);
        }

        const int n = ansi - 16;
        int _b = n % 6;
        int _g = (n - _b) / 6 % 6;
        int _r = (n - _b - _g * 6) / 36 % 6;
        _b = _b ? _b * 40 + 55 : 0;
        _r = _r ? _r * 40 + 55 : 0;
        _g = _g ? _g * 40 + 55 : 0;

        return new Color(_r / 255.0, _g / 255.0, _b / 255.0);
    }

    static Color getFromHex(string hex) {
        auto rg = regex(r"/^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i");
        auto m = matchAll(hex, rg);
        m.popFront();
        float _r = to!int(m.front.hit, 16) / 255; m.popFront();
        float _g = to!int(m.front.hit, 16) / 255; m.popFront();
        float _b = to!int(m.front.hit, 16) / 255; m.popFront();
        return new Color(to!float(_r), to!float(_g), to!float(_b));
    }

    int getAnsi8(bool isBackground) {
        // TODO
        /*
        * 39 - default foreground, 49 - default backgound
        * Main colors are from 30 - 39, light variant is 90 - 97.
        * 97 is white, 30 is black. to get background - add 10 to color code
        * goes like:
        * black, red, green, yellow, blue, magenta, cyan, lgray
        * then repeat with lighter variation
        */
        return 0;
    }

    int getAnsi() {
        // TODO
        /*
        * 256 ANSI color coding is:
        * 0 - 14 Special colors, probably check by hand
        * goes like:
        * black, red, green, yellow, blue, magenta, cyan, lgray
        * then repeat with lighter variation
        * 16 - 231 RGB colors with color coding like this:
        * Pure R component is on 16, 52, 88, 124, 160, 196. Aka map(r, comp)
        * B component is r +0..5
        * G component is rb +0,6,12,18,24,30 (but not 36 coz it's next red)
        * in end rgb coding, considering mcol = floor(col*5)
        * rgbansi = 16 + (16 * r) + (6 * g) + b;
        * 232 - 255 Grayscale from dark to light
        * refer to https://misc.flogisoft.com/_media/bash/colors_format/256-colors.sh-v2.png
        */
        return 0;
    }

    string getHex() {
        int _r = to!int(this.r * 255.0);
        int _g = to!int(this.g * 255.0);
        int _b = to!int(this.b * 255.0);
        string col = to!string((1 << 24) + (_r << 16) + (_g << 8) + _b, 16);
        return "#" ~ col[1 .. col.length];
    }

    float getLuma() {
        return (0.2126 * this.r + 0.7152 * this.g + 0.0722 * this.b);
    }

    Color clamped() {
        this.r = fClamp(this.r, 0, 1);
        this.g = fClamp(this.g, 0, 1);
        this.b = fClamp(this.b, 0, 1);
        return this;
    }
}