module pxv.lib.image;

public import stb.image: STBImage = Image;
public import stb.image: Pixel = Color;

version (Have_speedy_stdio)
    import speedy.stdio: writeln;
else
    import std.stdio: writeln;

import std.conv: to;
import std.algorithm.comparison: max;

import core.stdc.stdlib: exit;
const int alphaThreshold = 64;

Image loadImage(string filepath) {
    STBImage stbimg;
    try {
        stbimg = new STBImage(filepath);
    } catch (Exception e) {
        writeln(e.msg);
        exit(1);
    }
    Image img = Image(
        stbimg.opSlice, stbimg.w, stbimg.h,
        stbimg.frames, cast(uint[]) (stbimg.delays[0..stbimg.frames]),
        stbimg.frames > 2);
    return img;
}

Image loadImageURL(string url) {
    import std.net.curl;
    import std.file: tempDir;
    import std.path: dirSeparator;
    download(url, tempDir ~ "pxv-tempFile");
    // writeln(tempDir ~ "pxv-tempFile");
    return loadImage(tempDir ~ "pxv-tempFile");
    // STBImage stbimg;
    // HTTP http = HTTP();
    // // http.verbose(true);
    // string content = cast(string) get!(HTTP, ubyte)(url, http);
    // writeln(content);
    // try {
    //     stbimg = new STBImage(cast(void[]) content);
    // } catch (Exception e) {
    //     writeln(e.msg);
    //     exit(1);
    // }
    // Image img = Image(
    //     stbimg.opSlice, stbimg.w, stbimg.h,
    //     stbimg.frames, cast(uint[]) (stbimg.delays[0..stbimg.frames]),
    //     stbimg.frames > 2);
    // return img;
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

