# Vala
___

## style
- Prefer ``async/yeild``
- ``snake_case`` for methods/functions
- Type indentifiers in ``CamelCase``
- Enum members and constants in ALL_CAPS, words seperated by underscores
- use implicit typing i.e ``var`` only when the type is obvious
- only use casting with ``as`` if you also check the value for ``null`` after
- Use ``@"blub $foo blob $(bar.baz)\n"`` instead of ``"blub " + foo.to_string() + ...``
- Initialize objects with properties where possible: 
```
// OK
var button = new Gtk.Button () {
    label = "Click Me!",
    halign = CENTER,
    css_classes = { "suggested-action", "pill" }
};

// NOT OK
var button = new Gtk.Button ();
button.label = "Click Me!";
button.halign = CENTER;
button.add_css_class ("suggested-action");
button.add_css_class ("pill");
```
- use properties ``int count { get; private set; }`` instead of declaring getter and setters

## Logging 
- Use message (), warning () and critical () for debug messages (depending on the severity)
- Use print ()/stdout.printf () for messages that are intended to be seen by the user



