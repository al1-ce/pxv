module modules.vector;

class Vector2(T) {
    T x;
    T y;

    alias ZERO = () => new Vector2(0, 0);
    alias ONE = () => new Vector2(1, 1);
    alias NEG = () => new Vector2(-1, -1);
    alias LEFT = () => new Vector2(-1, 0);
    alias UP = () => new Vector2(0, 1);
    alias RIGHT = () => new Vector2(1, 0);
    alias DOWN = () => new Vector2(0, -1);

    this(T x, T y) {
        this.x = x;
        this.y = y;
    }

    this() {
        this(0, 0);
    }
}

alias Vector2f = Vector2!float;
alias Vector2i = Vector2!int;