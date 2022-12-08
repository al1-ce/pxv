import std.algorithm : canFind, clamp, countUntil, find, max, min, startsWith;
import std.conv : to;
import std.file;
import std.format : format;
import std.getopt;
import std.math : floor;
import std.range;
import std.stdio : File, write, writef, writefln, writeln;
import std.string : isNumeric;
import std.traits : isPointer;
import std.array: popFront, join, split;
import std.path: buildNormalizedPath, absolutePath, expandTilde;

import core.thread: Thread;
import core.time: msecs;
import core.sys.posix.signal;
import core.stdc.stdlib: exit;
import core.stdc.stdio: printf;

import stb.image: STBImage = Image;
import stb.image: Pixel = Color;

import sily.color;
import sily.bashfmt;
import sily.getopt;
import sily.vector: ivec2;
import sily.terminal;

// cls && /g/pxv/bin/pxv ~/Pictures/20407219.png ~/Pictures/roofline-girl-1s-3840x2400.jpg ~/Pictures/anime-wallpaper.jpg
// cls && ./bin/pxv ~/Pictures/20407219.png 

string brightChars = r" .`^,:;!-~=+<>[]{}*JS?AX#%@";

const int alphaThreshold = 64;

alias fFloor = (T) => floor(to!float(T));
alias fFloorToInt = (T) => to!int(fFloor(T));
alias fClamp = (T, M, A) => clamp(to!float(T), to!float(M), to!float(A));
alias fClampToInt = (T, M, A) => to!int(fClamp(T, M, A));

string fixPath(string path) { return path.buildNormalizedPath.expandTilde.absolutePath; } 

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
    ColorType color = ColorType.ansi256;
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

private Config conf;

extern(C) void handler(int num) nothrow @nogc @system {
    printf("\033[m\033[?25h\n");
    exit(num);
}

int main(string[] args) {
    signal(SIGINT, &handler);
    // FIXME: size works incorrectly
    // FIXME: --once flag doesnt work
    // FIXME: too much flicker
    GetoptResult help;
    try {
        help = getopt(
            args,
            config.bundling, config.passThrough, std.getopt.config.caseSensitive,
            "columns|c", "Sets width/columns", &conf.width,
            "rows|r", "Sets height/rows", &conf.height,
            "size|s", "Matches size. Must be \'width\', \'height\' or \'fit\'", &conf.size,

            "color|C", "Sets color type. Must be \'ansi8\', \'ansi256\', \'truecolor\'", &conf.color,
            "grayscale|g", "Renders image in grayscale", &conf.grayscale,
            "lowres|l", "Renders image in half of resolution", &conf.lowres,
            
            "ascii|i", "Uses ascii palette", &conf.useAscii,
            "palette|p", "Sets ascii palette for output", &conf.asciiPalette,
            "background|b", "Disables background", &conf.hideBackground,
            // "unicode|u", "Uses unicode to mimic image as much as possible", &conf.useUnicode,
            "once|o", "If image is gif and flag is set then it's going to do only one loop", &conf.loopOnce,
            "still|S", "Shows only first frame in gif", &conf.still,
            "frame|f", "Shows only N frame in gif", &conf.frame
        );
    } catch (Exception e) {
        writeln(e.msg);
        return 1;
    }

    // help routine
    uint _opt = 0;
    if (help.helpWanted || args.length == 1) {
        printGetopt(
            "Usage: pxv [args] image-file",
            "Size",
            help.options[_opt..(_opt += 3)],
            "Colors",
            help.options[_opt..(_opt += 3)],
            "Misc",
            help.options[_opt..(_opt += 6)],
        );
        return 0;
    }

    if (conf.lowres && conf.hideBackground && !conf.useAscii) {
        conf.hideBackground = false;
    }

    string[] opts = args[1..$];

    foreach (opt; opts) {
        // checking filepath
        string filepath = opt.fixPath;

        if (!filepath.exists()) {
            writefln("No file: \'%s\'.", filepath);
            continue;
        }

        STBImage stbimg;
        try {
            stbimg = new STBImage(filepath);
        } catch (Exception e) {
            writeln(e.msg);
            continue;
        }
        Image img = Image(
            stbimg.opSlice, stbimg.w, stbimg.h, 
            stbimg.frames, cast(uint[]) (stbimg.delays[0..stbimg.frames]), 
            stbimg.frames > 2);

        int trows = terminalHeight();
        int tcolumns = terminalWidth();

        float ratio = img.h / 1.0f / img.w;

        bool isMatchingHeight = false;

        if (conf.width != 0) {
            tcolumns = conf.width;
        }

        if (conf.height != 0) {
            trows = conf.height;
            isMatchingHeight = true;
        }

        if (img.isGif) { conf.size = MatchSize.fit; }

        // trows *= 2;

        if (conf.size == MatchSize.height) isMatchingHeight = true;
        if (conf.size == MatchSize.width) isMatchingHeight = false;
        if (conf.size == MatchSize.fit) {
            int th = terminalHeight() * 2;
            int tw = terminalWidth();
            int ih = img.h;
            int iw = img.w;
            if (th > tw) { // terminal tall
                if (ih > iw) { // image tall
                    isMatchingHeight = true;
                } else {
                    isMatchingHeight = false;
                }
            } else { // terminal wide
                isMatchingHeight = true;
                // if (ih > iw) {
                //     isMatchingHeight = true;
                // } else {
                // }
            }
        }
        
        if (isMatchingHeight && conf.width == 0) {
            tcolumns = to!int(trows * 2 / ratio);
        } else 
        if (conf.height == 0) {
            trows = to!int(tcolumns / 2 * ratio);
        }

        if (conf.asciiPalette != "") {
            brightChars = conf.asciiPalette;
        }


        img.resizeImage(tcolumns, trows * 2);

        // writefln("{%d, %d}", img.w, img.h);
        // int width = img.w;
        int height = img.h;
        if (img.isGif) {
            // screenEnableAltBuffer();
        }
        cursorHide();

        int frame = 0;

        if (conf.still) {
            img.isGif = false;
            img.frameCount = 1;
        }
        if (conf.frame != -1) {
            frame = conf.frame;
            img.isGif = false;
            img.frameCount = frame + 1;
        }

        for (; frame < img.frameCount; ++frame) {
            // fwrite(FR.fullreset);
            cursorMoveTo(1);
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

            // is gif and not at end
            if (img.isGif && frame < img.frameCount - 2) {
                Thread.sleep(img.delays[frame].msecs);
                eraseLines(img.h / 2 );
                // moveCursorUp();
            } else 
            // is gif and at end and looping
            // if (img.isGif && frame == img.frameCount - 1 && conf.loopOnce == false) {
            if (frame == img.frameCount - 1) {
                if (conf.loopOnce) {
                    break;
                } else 
                if (img.isGif) {
                    Thread.sleep(img.delays[frame].msecs);
                    eraseLines(img.h / 2 );
                    frame = 0;
                }
            } else {
                break;
            }

        } // next frame

        if (img.isGif) {
            // screenDisableAltBuffer();
        }
        scope(exit) {
            fwriteln(FR.fullreset);
        }

    } // next image

    cursorShow();

    // success
    return 0;
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

struct Image {
    Pixel[] data;
    uint w;
    uint h;
    uint frameCount;
    uint[] delays;
    bool isGif;
}

Pixel opIndex(Image img, uint x, uint y) {
    return img.data[y * img.w + x];
}

Pixel opIndex(Image img, uint x, uint y, uint frame) {
    return img.data[y * img.w + x + frame * img.w * img.h];
}

Color pixelColor(Pixel p) {
    return Color(p.r / 255.0, p.g / 255.0, p.b / 255.0);
}

void resizeImage(ref Image img, uint newWitdth, uint newHeight) {    
    uint w = newWitdth;
    uint h = newHeight;

    Pixel[] pix = new Pixel[](newWitdth * newHeight * img.frameCount);
    float xsc = img.w.to!float / w / 1f;
    float ysc = img.h.to!float / h / 1f;
    uint xsci = max(1, cast(int) (img.w / w / 1f));
    uint ysci = max(1, cast(int) (img.h / h / 1f));
    uint wh = xsci * ysci;

    for (uint f = 0; f < img.frameCount; ++f) {
        ulong offset = f * img.w * img.h;
        for (uint y = 0; y < h; ++y) {
            for (uint x = 0; x < w; ++x) {
                uint r = 0;
                uint g = 0;
                uint b = 0;
                uint a = 0;
                
                uint srcx = cast(int) (xsc * x);
                uint srcy = cast(int) (ysc * y);
                for (uint yi = 0; yi < ysci; ++yi) {
                    for (uint xi = 0; xi < xsci; ++xi) {
                        ulong ipos = (srcy + yi) * img.w + srcx + xi + offset;

                        r += img.data[ipos].r;
                        g += img.data[ipos].g;
                        b += img.data[ipos].b;
                        a += img.data[ipos].a;
                    }
                }
                uint pos = (y * w + x) + w * h * f;
                
                pix[pos].r = to!ubyte(r / wh); 
                pix[pos].g = to!ubyte(g / wh);
                pix[pos].b = to!ubyte(b / wh);
                pix[pos].a = to!ubyte(a / wh);
                
            }
        }
    }

    img.w = w;
    img.h = h;
    img.data = pix;
}

bool transparent(Pixel p) {
    return p.a < alphaThreshold;
}

char getChar(Color _col) {
    int maxPos = brightChars.length.to!int - 1;
    int p = clamp( _col.luminance() * maxPos, 0, maxPos).to!int;
    return brightChars[p];
}
