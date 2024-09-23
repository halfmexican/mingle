## **Mingle Style Guide**

### **1. General Coding Style**

- **Prefer `async/yeild`** for asynchronous programming.
- **Use `snake_case`** for all method and function names:
  - Example: `void perform_async_task()`
- **Type identifiers** should be in `CamelCase`:
  - Example: `GtkButton`, `MyClass`
- **Enum members and constants** should be in **ALL_CAPS**:
  - Use underscores to separate words.
  - Example: `MY_ENUM_VALUE`, `MAX_RETRIES`
- **Implicit typing (`var`)** should only be used when the type is obvious:
  - Example: `var list = new List<int>();`
- **Casting with `as`** should only be done if you **check for `null`** afterward:
  ```vala
  var button = widget as Gtk.Button;
  if (button != null) {
      // Safe to use button
  }
  ```
- Use **string interpolation** with `@"..."` for cleaner string concatenation:
  ```vala
  var name = "Alice";
  message(@"Hello, $name!");
  ```

### **2. Object Initialization**

- **Use inline property initialization** whenever possible. This makes the code cleaner and easier to read:
  - **Preferred:**
    ```vala
    var button = new Gtk.Button() {
        label = "Click Me!",
        halign = Gtk.Align.CENTER,
        css_classes = { "suggested-action", "pill" }
    };
    ```
  - **Not Preferred:**
    ```vala
    var button = new Gtk.Button();
    button.label = "Click Me!";
    button.halign = Gtk.Align.CENTER;
    button.add_css_class("suggested-action");
    button.add_css_class("pill");
    ```

### **3. Properties and Accessors**

- Use **property syntax** for getters and setters instead of manually declaring methods:
  ```vala
  public int count { get; private set; }
  ```

### **4. Logging and Messaging**

- Use **`message()`, `warning()`, `critical()`** for logging debug information:
  - `message()`: General informational messages
  - `warning()`: Warnings that don’t require immediate action but could lead to issues
  - `critical()`: Serious issues that need immediate attention
  ```vala
  message("Process started.");
  warning("Low memory.");
  critical("File not found.");
  ```
- Use **`print()` or `stdout.printf()`** for messages intended for users:
  ```vala
  print("Process complete.");
  stdout.printf("User %s logged in\n", username);
  ```
