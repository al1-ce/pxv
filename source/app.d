import std.stdio: write, writef, writefln, writeln, File;
import std.file;
import std.format: format;
import std.string: isNumeric;
import std.conv: to;
import std.math: floor;
import std.algorithm: canFind, startsWith, find, countUntil, clamp, max, min;
import std.range;
import std.traits: isPointer;
import core.sys.posix.sys.ioctl;
import modules.color;
import dlib.image;

// Color lib ref: https://github.com/yamadapc/d-colorize/
// DLib link: https://code.dlang.org/packages/dlib

const string eolColToken = "\033[0m";
const string helpString = `Usage: cascii [args] image-file

    -h, --help              displays this message
    -w, --width             sets width/colums. Terminal width by default
    -g, --grayscale         sets grayscale
    -t, --truecolor         enables truecolor
    -r, --restrict          restricted 8/16bit palette
    -f, --fancy             mimics image as much as possible
    -p, --palette           sets ascii palette for output, doesnt work with -f
    -b, --background        enables background colors
`;

/* 
 * Return states 
 * 0 - success
 * 1 - Incorrect arguments
 * 2 - Image loading exceptions
 */
int main(string[] args) {
    // help routine
    if (args.canFind("-h") || args.canFind("--help") || args.length == 1) {
        writeln(helpString);
        return 0;
    }

    // checking filepath
    string filepath = args[args.length - 1];

    if (startsWith(filepath, '-') > 0) {
        writeln("Missing image path");
        return 1;
    }

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

    // arguments
    winsize w;
    ioctl(0, TIOCGWINSZ, &w);
    int terminalWidth = w.ws_col;
    if (args.canFind("-w") || args.canFind("--width")) {
        int w1idx = to!int(countUntil(args, ["-w"]));
        int w2idx = to!int(countUntil(args, ["--width"]));
        if (w1idx != -1) {
            string arg = args[min(w1idx + 1, args.length - 1)];
            if (isNumeric(arg)) {
                terminalWidth = to!int(to!int(arg));
            }
        }
        if (w2idx != -1) {
            string arg = args[min(w2idx + 1, args.length - 1)];
            if (isNumeric(arg)) {
                terminalWidth = to!int(to!int(arg));
            }
        }
    }
    terminalWidth = min(terminalWidth, w.ws_col);


    const float yfix = 1.75;
    const int rate = width / terminalWidth;
    const int terminalHeight = to!int(floor((height / rate) / yfix));

    for (int y = 0; y < terminalHeight; ++y) {
        for (int x = 0; x < terminalWidth; ++x) {
            int xpos = to!int(clamp(floor(to!float(x * rate)), 0, width));
            int ypos = to!int(clamp(floor(to!float(y * rate * yfix)), 0, height));
            auto pix = img.opIndex(xpos, ypos);
            writef(" %s", getColTokenBack(new DColor(pix.r, pix.g, pix.b)));
        }
        writeln(eolColToken);
    }

    // success
    return 0;
}

string getColToken8(string ansi) {
    return format("\033[%sm", ansi);
}

string getColToken(string ansi) {
    return format("\033[38;5;%sm", ansi);
}

string getColToken(DColor col) {
    return format("\033[38;2;%s;%s;%sm", 
                    to!string(floor(col.r * 255)), 
                    to!string(floor(col.g * 255)), 
                    to!string(floor(col.b * 255)));
}

string getColTokenBack(string ansi) {
    return format("\033[48;5;%sm", ansi);
}

string getColTokenBack(DColor col) {
    return format("\033[48;2;%s;%s;%sm", 
                    to!string(floor(col.r * 255)), 
                    to!string(floor(col.g * 255)), 
                    to!string(floor(col.b * 255)));
}