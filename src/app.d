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

import core.sys.posix.sys.ioctl;

import dlib.image;

import sily;

import modules.color;
import modules.vector : Vector2i;

// Color lib ref: https://github.com/yamadapc/d-colorize/
// DLib link: https://code.dlang.org/packages/dlib

const string eolColToken = "\033[0m";

string brightChars = r" .`^,:;!-~=+<>[]{}*JS?#%@AX";

alias fFloor = (T) => floor(to!float(T));
alias fFloorToInt = (T) => to!int(fFloor(T));
alias fClamp = (T, M, A) => clamp(to!float(T), to!float(M), to!float(A));
alias fClampToInt = (T, M, A) => to!int(fClamp(T, M, A));

string fixPath(string path) { return path.buildNormalizedPath.expandTilde.absolutePath; } 

/* 
 * Return states 
 * 0 - success
 * 1 - Incorrect arguments
 * 2 - Image loading exceptions
 */
int main(string[] args) {

    int cwidth = 0;
    bool cgray = false;
    bool ctruecolor = false;
    bool crestrict = false;
    bool cfancy = false;
    string cpalette = "";
    // bool cbackground;

    auto help = getopt(
        args,
        config.bundling, config.passThrough,
        "width|w", "Sets width/columns", &cwidth,
        "grayscale|g", "Sets grayscale", &cgray,
        "truecolor|t", "Enables truecolor", &ctruecolor,
        "restrict|r", "Restricts to 8/16bit palette", &crestrict,
        "fancy|f", "Mimics image as much as possible", &cfancy,
        "palette|p", "Sets ascii palette for output", &cpalette,
        // "background|b", "Enables background colors", &cbackground
    );

    // help routine
    if (help.helpWanted || args.length == 1) {
        printGetopt(
            "Usage: cascii [args] image-file",
            "Options",
            help.options
        );
        return 0;
    }

    string[] opts = args.dup;
    opts.popFront();

    // checking filepath
    string filepath = opts.join.fixPath;

    if (!filepath.exists()) {
        writeln("No such file");
        return 2;
    }

    // image loading routine
    SuperImage img;
    try {
        img = loadImage(filepath);
    } catch (Exception) {
        writeln("Cannot open image");
        return 2;
    }
    
    int width = img.width;
    int height = img.height;

    winsize w;
    ioctl(0, TIOCGWINSZ, &w);
    int terminalWidth = w.ws_col;

    if (cwidth != 0) {
        terminalWidth = cwidth;
    }
    terminalWidth = max(min(terminalWidth, w.ws_col), 0);

    if (cpalette != "") {
        brightChars = cpalette;
    }


    const float yfix = 1.75;
    const int rate = width / terminalWidth;
    const int terminalHeight = to!int(floor((height / rate) / yfix));

    for (int y = 0; y < terminalHeight; ++y) {
        for (int x = 0; x < terminalWidth; ++x) {
            int xpos = fClampToInt(fFloor(x * rate), 0, width);
            int ypos = fClampToInt(fFloor(y * rate * yfix), 0, height);
            int wpos = fClampToInt(fFloor(x + 1) * rate, 0, width) - xpos;
            int hpos = fClampToInt(fFloor(y + 1) * rate * yfix, 0, height) - ypos;
            
            auto pix = img.opIndex(fFloorToInt(xpos + wpos / 2), fFloorToInt(ypos + hpos / 2));
            Color mainCol = new Color(pix.r, pix.g, pix.b);
            Color avgCol = getAvgColor(img, new Vector2i(xpos, ypos), new Vector2i(wpos, hpos));
            writef("%s%s%s", getColTokenBack(avgCol), getColToken(mainCol), getChar(mainCol));
        }
        writeln(eolColToken);
    }

    // success
    return 0;
}

Color getAvgColor(SuperImage img, Vector2i stPos, Vector2i whPos) {
    Color col = Color.WHITE;

    for (int y = stPos.y; y < stPos.y + whPos.y; ++y) {
        for (int x = stPos.x; x < stPos.x + whPos.x; ++x) {
            auto pix = img.opIndex(x, y);
            Color c = new Color(pix.r, pix.g, pix.b);
            col.r += c.r;
            col.g += c.g;
            col.b += c.b;
        }
    }

    col.r /= whPos.x * whPos.y;
    col.g /= whPos.x * whPos.y;
    col.b /= whPos.x * whPos.y;
    
    return col.clamped();
}

char getChar(Color col) {
    // int p = fFloorToInt((1 - col.getLuma()) * (to!int(brightChars.length) - 1));
    int p = fFloorToInt((col.getLuma()) * (to!int(brightChars.length) - 1));
    return brightChars[p];
}

string getColToken8(string ansi) {
    return format("\033[%sm", ansi);
}

string getColToken(string ansi) {
    return format("\033[38;5;%sm", ansi);
}

string getColToken(Color col) {
    return format("\033[38;2;%s;%s;%sm", 
                    to!string(floor(col.r * 255)), 
                    to!string(floor(col.g * 255)), 
                    to!string(floor(col.b * 255)));
}

string getColTokenBack(string ansi) {
    return format("\033[48;5;%sm", ansi);
}

string getColTokenBack(Color col) {
    return format("\033[48;2;%s;%s;%sm", 
                    to!string(floor(col.r * 255)), 
                    to!string(floor(col.g * 255)), 
                    to!string(floor(col.b * 255)));
}
