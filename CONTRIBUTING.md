# Coding Style #

## Tabs and indentation ##

No tab characters should be used. Use 4 spaces instead of tabs.

## Identifiers ##

* Class names: *CamelCase* with uppercase first letter
* Method and property names: *camelCase* with lowercase first letter
* Private and protected class and struct fields: *_camelCase* prepend with underscore
* Signal names: *camelCase*
* Enum member names: *camelCase*

## Spaces ##

Always put space after comma or semicolon if there are more items in the same line

```d
auto list = [1, 2, 3, 4, 5];
```

Usually no spaces after opening or before closing `[]` `()`.
Spaces may be added to improve readability when there is a sequence of brackets of the same type.

```d
auto y = (x * x + ( ((a - b) + c) ) * 2);
```

Use spaces before and after `== != && || + - * /` etc.

## Brackets ##

Use curly braces for `if`, `switch`, `for`, `foreach` - preferable placed on the same lines as keyword:

```d
if (a == b) {
    //
} else {
    //
}

foreach (item; list) {
    writeln(item);
}
```

Cases in switch should be intended:

```d
switch(action.id) {
    case 1:
        break;
    default:
        break;
}
```
