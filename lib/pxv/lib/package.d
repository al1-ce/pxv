module pxv.lib;

import std.algorithm : canFind, clamp, countUntil, find, max, min, startsWith;
import std.conv : to;
import std.file;
import std.format : format;
import std.getopt;
import std.math : floor;

import sily.color;
import sily.bashfmt: BG, FG, FM, FR;
import sily.vector: ivec2;
import sily.terminal;
// import speedy.stdio : write, writef, writefln, writeln;

import pxv.lib.image;
// cls && /g/pxv/bin/pxv ~/Pictures/20407219.png ~/Pictures/roofline-girl-1s-3840x2400.jpg ~/Pictures/anime-wallpaper.jpg
// cls && ./bin/pxv ~/Pictures/20407219.png 

string brightChars = r" .`^,:;!-~=+<>[]{}*JS?AX#%@";

const int alphaThreshold = 64;

alias fFloor = (T) => floor(to!float(T));
alias fFloorToInt = (T) => to!int(fFloor(T));
alias fClamp = (T, M, A) => clamp(to!float(T), to!float(M), to!float(A));
alias fClampToInt = (T, M, A) => to!int(fClamp(T, M, A));

string upperBlock = "\u2580";
string lowerBlock = "\u2584";

enum MatchSize {
    none, width, height, fit
}

enum ColorType {
    ansi8, ansi256, truecolor
}

struct Config {
    int width = 0;
    int height = 0;
    MatchSize size = MatchSize.none;
    ColorType color = ColorType.truecolor;
    bool grayscale = false;
    bool lowres = false;
    bool useAscii = false;
    string asciiPalette = "";
    bool hideBackground = false;
    bool useUnicode = false;
    bool loopOnce = false;
    bool still = false;
    int frame = -1;
}

Config conf;
private string _out = "";

string getImageString(Config conf, Image img) {
    _out = "";
    
    if (conf.lowres && conf.hideBackground && !conf.useAscii) {
        conf.hideBackground = false;
    }

    int trows = conf.height;
    int tcolumns = conf.width;

    if (conf.asciiPalette != "") {
        brightChars = conf.asciiPalette;
    }

    int height = img.h;
    
    int frame = 0;
    // _out ~= "\033[?25l";
    if (conf.frame != -1 && conf.frame < img.frameCount) {
        frame = conf.frame;
    }
    // for (; frame < img.frameCount; ++frame) {
        // fwrite(FR.fullreset);
        // cursorMoveTo(1);
    _out ~= "\033[1G";
    for (int y = 0; y < trows; ++y) {
        for (int x = 0; x < tcolumns / (conf.lowres ? 2 : 1); ++x) {

            Pixel upperPix = img.opIndex(x * (conf.lowres ? 2 : 1), y * 2, frame);
            Color upperCol = upperPix.pixelColor();
            if (conf.grayscale) upperCol = Color(upperCol.luminance);
            if (!conf.lowres) {
                if (y * 2 < height - 1) {
                    Pixel lowerPix = img.opIndex(x, y * 2 + 1, frame);
                    Color lowerCol = lowerPix.pixelColor();
                    if (conf.grayscale) lowerCol = Color(lowerCol.luminance);

                    if (upperPix.transparent) {
                        if (lowerPix.transparent) {
                            write(FR.fullreset ~ " ");
                        } else {
                            if (conf.useAscii) {
                                char c = lowerCol.getChar();
                                writePixel!true(BG.reset, lowerCol, [c]);
                            } else {
                                writePixel!false(BG.reset, lowerCol, lowerBlock);
                            }
                        }
                    } else { // upperPix.transparent
                        if (lowerPix.transparent) {
                            if (conf.useAscii) {
                                writePixel!true(upperCol, FG.reset, " ");
                            } else {
                                writePixel!false(BG.reset, upperCol, upperBlock);
                            }
                        } else {
                            if (conf.useAscii) {
                                char c = lowerCol.getChar();
                                writePixel(upperCol, lowerCol, [c]);
                            } else {
                                writePixel(upperCol, lowerCol, lowerBlock);
                            }
                        }
                    }
                } else { // y * 2 < height - 1
                    if (upperPix.transparent) {
                        write(FR.fullreset ~ " ");
                    } else {
                        if (conf.useAscii) {
                            writePixel!true(upperCol, FG.reset, " ");
                        } else {
                            writePixel!false(BG.reset, upperCol, upperBlock);
                        }
                    }
                }
            } else { // chalf
                if (y * 2 < height - 1) {
                    Pixel lowerPix = img.opIndex(x * 2, y * 2 + 1, frame);
                    Color lowerCol = lowerPix.pixelColor();
                    if (conf.grayscale) lowerCol = Color(lowerCol.luminance);

                    if (upperPix.transparent) {
                        if (lowerPix.transparent) {
                            write(FR.fullreset ~ "  ");
                        } else {
                            if (conf.useAscii) {
                                char c = lowerCol.getChar();
                                writePixel!true(BG.reset, lowerCol, [c, c]);
                            } else {
                                writePixel!false(BG.reset, lowerCol, "  ");
                            }
                        }
                    } else { // upperPix.transparent
                        if (lowerPix.transparent) {
                            if (conf.useAscii) {
                                writePixel!true(upperCol, FG.reset, "  ");
                            } else {
                                writePixel!false(BG.reset, upperCol, "  ");
                            }
                        } else {
                            if (conf.useAscii) {
                                char c = lowerCol.getChar();
                                writePixel(upperCol, lowerCol, [c, c]);
                            } else {
                                writePixel(upperCol, lowerCol, "  ");
                            }
                        }
                    }
                } else { // y * 2 < height - 1
                    if (upperPix.transparent) {
                        fwrite(FR.fullreset);
                    } else {
                        if (conf.useAscii) {
                            writePixel!true(upperCol, FG.reset, "  ");
                        } else {
                            writePixel!true(BG.reset, upperCol, "  ");
                        }
                    }
                }
            }
            
        } // x
        if (img.isGif && y == trows - 1) {
            fwrite(FR.fullreset);
        } else {
            fwriteln(FR.fullreset);
        }
    } // y


    return _out;
}

void write(string t) {
    _out ~= t;
}

void writeln(string t) {
    _out ~= t ~ "\n";
}

void fwrite(A...)(A args) {
    foreach (arg; args) {
        write(cast(string) arg);
    }
}

void fwriteln(A...)(A args) {
    foreach (arg; args) {
        write(cast(string) arg);
    }
    write("\n");
}

void writePixel(bool fgOnly = false)(BG bg, Color fg, string c) {
    if (fgOnly || !conf.hideBackground) {
        if (conf.color == ColorType.ansi8)
            fwrite(fg.toAnsi8String(), c);
        else if (conf.color == ColorType.truecolor)
            fwrite(fg.toTrueColorString(), c);
        else
            fwrite(fg.toAnsiString(), c);
    } else {
        if (conf.color == ColorType.ansi8)
            fwrite(bg, fg.toAnsi8String(), c);
        else if (conf.color == ColorType.truecolor)
            fwrite(bg, fg.toTrueColorString(), c);
        else
            fwrite(bg, fg.toAnsiString(), c);
    }
}

void writePixel(bool bgOnly = false)(Color bg, FG fg, string c) {
    if (conf.hideBackground) {
        write(c);
        return;
    }
    if (bgOnly) {
        if (conf.color == ColorType.ansi8)
            fwrite(bg.toAnsi8String(true), c);
        else if (conf.color == ColorType.truecolor)
            fwrite(bg.toTrueColorString(true), c);
        else
            fwrite(bg.toAnsiString(true), c);
    } else {
        if (conf.color == ColorType.ansi8)
            fwrite(fg, bg.toAnsi8String(true), c);
        else if (conf.color == ColorType.truecolor)
            fwrite(fg, bg.toTrueColorString(true), c);
        else
            fwrite(fg, bg.toAnsiString(true), c);
    }
}

void writePixel(Color bg, Color fg, string c) {
    if (!conf.hideBackground) {
        if (conf.color == ColorType.ansi8)
            fwrite(bg.toAnsi8String(true), fg.toAnsi8String(), c);
        else if (conf.color == ColorType.truecolor)
            fwrite(bg.toTrueColorString(true), fg.toTrueColorString(), c);
        else
            fwrite(bg.toAnsiString(true), fg.toAnsiString(), c);
    } else {
        if (conf.color == ColorType.ansi8)
            fwrite(fg.toAnsi8String(), c);
        else if (conf.color == ColorType.truecolor)
            fwrite(fg.toTrueColorString(), c);
        else
            fwrite(fg.toAnsiString(), c);
    }
}

Color pixelColor(Pixel p) {
    return Color(p.r / 255.0, p.g / 255.0, p.b / 255.0);
}


char getChar(Color _col) {
    int maxPos = brightChars.length.to!int - 1;
    int p = clamp( _col.luminance() * maxPos, 0, maxPos).to!int;
    return brightChars[p];
}
