# wire

Wire is an extendable and customisable dynamic HTML template engine based on element attributes and HTML5 user-defined elements.

### Package Information

- **Name:** wire
- **Version:** 1.0.0
- **Homepage:** https://github.com/mcfriend99/wire
- **Tags:** html, template, template-engine, dynamic, wire
- **Author:** Richard Ore <eqliqandfriends@gmail.com>
- **License:** [MIT](https://github.com/mcfriend99/wire/blob/main/LICENSE)

### Basic Usage

```
import wire

var wireapp = wire()
echo wireapp.renderString('mytemplate')
```

### Syntax Example

Here's a quick sample of a Wire template.

```html5
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Document</title>
</head>
<body>
  <h1>Welcome to OurSite</h1>
  <div w-if="logged_in">
    Your name is {{ username }}.
    <div w-for="posts" w-key="post">
      <a href="{! base_url !}/post/1">{{ post.title|upper }}</a>
    </div>
  </div>
  <div w-not="logged_in">Please Login!</div>
</body>
</html>
```
