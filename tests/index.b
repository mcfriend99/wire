import ..app

var wire = app.wire({
  root: 'tests/wires',
  auto_init: true,
  functions: {
    reverse: | t, _ | {
      return ''.join(to_list(t).reverse())
    },
    equal: |t, v| {
      return t == v
    },
    string: | t, _ | {
      return to_string(t)
    },
    test: || {
      return 'It works!'
    }
  },
  elements: {
    main: |w, e| {
      return '<div></div>'
    }
  }
})

assert wire.render('test', {
  name: 'Richard',
}) == '<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Document</title>
</head>
<body>
  Richard
  {{ name }}
  <div>R</div><div>i</div><div>c</div><div>h</div><div>a</div><div>r</div><div>d</div>
  7
  drahciR
  eurt


  <div></div>
  R

  It works!
  {! test !}
</body>
</html>', 'Test `render()` Failed!'

assert wire.renderString('<p>{{name}}</p>', {
  name: 'Richard',
}) == '<p>Richard</p>', 'Test `renderString()` failed!'

echo 'Test Passed!'
