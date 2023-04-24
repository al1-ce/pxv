import std.algorithm : canFind, clamp, countUntil, find, max, min, startsWith;
import std.conv : to;
import std.file;
import std.format : format;
import std.getopt;
import std.math : floor;
import std.range;
import std.string : isNumeric;
import std.traits : isPointer;
import std.array: popFront, join, split;
import std.path: buildNormalizedPath, absolutePath, expandTilde;

import core.thread: Thread;
import core.time: msecs;
import core.sys.posix.signal;
import core.stdc.stdlib: exit;
import core.stdc.stdio: printf;

import sily.color;
import sily.bashfmt;
import sily.getopt;
import sily.vector: ivec2;
import sily.terminal;
import std.stdio: File;
import speedy.stdio : write, writef, writefln, writeln;

import pxv.lib;
import pxv.lib.image;

// cls && /g/pxv/bin/pxv ~/Pictures/20407219.png ~/Pictures/roofline-girl-1s-3840x2400.jpg ~/Pictures/anime-wallpaper.jpg
// cls && ./bin/pxv ~/Pictures/20407219.png 

string fixPath(string p) {
    return p.expandTilde.absolutePath.buildNormalizedPath;
}

private Config conf;

extern(C) void handler(int num) nothrow @nogc @system {
    printf("\033[m\033[?25h\n");
    exit(num);
}

int main(string[] args) {
    signal(SIGINT, &handler);
    bool isUrl = false;
    // FIXME: too much flicker, write into buffer and then write buffer itself
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
            "frame|f", "Shows only N frame in gif", &conf.frame,
            "url|U", "Sets URL instead of path", &isUrl
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

    string[] opts = args[1..$];

    foreach (opt; opts) {
        // checking filepath
        string filepath = opt;
        if (!isUrl) {
            filepath = opt.fixPath;
        }

        if (!filepath.exists && !isUrl) {
            writefln("No file: \'%s\'.", filepath);
            continue;
        }
        
        Image img;
        if (isUrl) {
            img = loadImageURL(filepath);
        } else {
            img = loadImage(filepath);
        }
        
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

        conf.width = tcolumns;
        conf.height = trows;

        img.resizeImage(tcolumns, trows * 2);

        // writefln("{%d, %d}", img.w, img.h);
        // int width = img.w;
        if (img.isGif) {
            // screenEnableAltBuffer();
            // terminalModeSetRaw(false);
        }
        cursorHide();

        int frame = 0;

        if (conf.still || !img.isGif) {
            img.isGif = false;
            img.frameCount = 2;
        }
        if (conf.frame != -1) {
            if (conf.frame >= img.frameCount -1) conf.frame = img.frameCount - 2;
            frame = conf.frame;
            img.isGif = false;
            img.frameCount = frame + 2;
        }

        for (; frame < img.frameCount - 1; ++frame) {
            conf.frame = frame;
            string im = getImageString(conf, img);
            write(im);
            // is gif and not at end
            if (img.isGif && frame < img.frameCount - 2) {
                Thread.sleep(img.delays[frame].msecs);
                eraseLines(img.h / 2 );
                // moveCursorUp();
            } else 
            // is gif and at end and looping
            // if (img.isGif && frame == img.frameCount - 1 && conf.loopOnce == false) {
            if (frame == img.frameCount - 2) {
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
            // if (img.isGif) if (kbhit) { int g = getch(); if (g == 3 || g == 17) break; }

        } // next frame
        scope(exit) {
            sily.bashfmt.fwriteln(FR.fullreset);
        }
        cursorShow();

    } // next image

    // success
    return 0;
}

