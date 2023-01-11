import os
import json
import iters
import cocoa
import reflect

var _default_root_dir = os.join_paths(os.cwd(), 'wires')

var _var_regex = '/(?<!%)\{\{\s*(?P<variable>([a-z_][a-z0-9_\-|="\']*(\.[a-z0-9_\-|="\']+)*))\s*\}\}/i'
var _fn_regex = '/(?<!%)\{\!\s*(?P<fn>[a-z0-9_]+)\s*\!\}/i'

var _if_drc = 'w-if'
var _not_drc = 'w-not'
var _for_drc = 'w-for'
var _key_drc = 'w-key'
var _value_drc = 'w-value'

var _default_functions = {
  length: | value | {
    if is_iterable(value)
      return value.length()
    die Exception('value is not an iterable')
  }
}

class Wire {
  Wire(options) {
    if options != nil and !is_dict(options)
      die Exception('dictionary expected')

    if !options options = {}
    self._configure(options)
  }

  _configure(options) {
    # extract configuration
    self._root_dir = options.get('root', _default_root_dir)
    var functions = options.get('functions', {})
    var elements = options.get('elements', {})
    var auto_init = options.get('auto_init', false)

    # setup functions
    self._functions = _default_functions.clone()
    if !is_dict(functions) {
      die Exception('functions option expect a dictionary')
    } else {
      for k, v in functions {
        if !is_function(v)
          die Exception('invalid wire function: ${k}')
      }
      self._functions.extend(functions)
    }

    # configure custom elements
    self._elements = {}
    if !is_dict(elements) {
      die Exception('elements option expect a dictionary')
    } else {
      for name, fn in elements {
        if !is_function(fn)
          die Exception('invalid wire element: ${name}')
        if reflect.get_function_metadata(fn).arity != 2
          die Exception('invalid function argument count for wire element: ${name}')
      }
      self._elements = elements
    }

    # confirm/auto create root directory as configured
    if !os.dir_exists(self._root_dir) {
      if !auto_init die Exception('wires directory not found.')
      else os.create_dir(self._root_dir)
    }
  }

  _get_attrs(attrs) {
    return iters.reduce(attrs, | dict, attr | {
      dict.set(attr.key, attr.value)
      return dict
    }, {})
  }

  _strip(txt) {
    # remove comments and surrounding white space
    return txt.trim().replace('/(?=<!--)([\s\S]*?)-->\\n*/m', '')
  }

  _strip_attr(element, ...) {
    var attrs = __args__
    element.attributes = iters.filter(element.attributes, | el | {
      return !attrs.contains(el.key)
    })
  }

  _extract_var(variables, _var, error) {
    var var_split = _var.split('|')
    if var_split {
      var _vars = var_split[0].split('.')
      var real_var
  
      if variables.contains(_vars[0]) {
        if _vars.length() > 1 {
          var final_var = variables[_vars[0]]
          iter var i = 1; i < _vars.length(); i++ {
            if is_dict(final_var) {
              final_var = final_var[_vars[i].matches('/^\d+$/') ? to_number(_vars[i]) : _vars[i]]
            } else if (is_list(final_var) or is_string(final_var)) and _vars[i].matches('/^\d+$/') {
              final_var = final_var[to_number(_vars[i])]
            } else {
              error('could not resolve "${_var}" at "${_vars[i]}"')
            }
          }
  
          real_var = final_var
        } else {
          real_var = variables[_vars[0]]
        }
  
        if var_split.length() > 1 {
          iter var i = 1; i < var_split.length(); i++ {
            var fn = var_split[i].split('=')
            if self._functions.contains(fn[0]) {
              if fn.length() == 1 {
                real_var = self._functions[fn[0]](real_var)
              } else {
                var val = fn[1]
                if val.match('/([\'"]).*\\1/') {
                  real_var = self._functions[fn[0]](real_var, val[1,-1])
                } else {
                  real_var = self._functions[fn[0]](real_var, self._extract_var(variables, val, error))
                }
              }
            } else {
              error('wire function "${fn[0]}" not declared')
            }
          }
        }
  
        return real_var
      } else {
        error('could not resolve "${_vars[0]}"')
      }
    } else {
      error('invalid variable "${_var}"')
    }
  
    return ''
  }

  _replace_funcs(content, error) {
    # prepare
    content = content.replace('%{!', '%{\x01!')
    # replace functions: {! fn !}
    # 
    # NOTE: This must come only just after variable replace as previous actions could generate or 
    # contain functions as well.
    var fn_vars = content.matches(_fn_regex)
    if fn_vars {
      # var_vars = json.decode(json.encode(fn_vars))
      iter var i = 0; i < fn_vars.fn.length(); i++ {
        var fn
        if (fn = self._functions.get(fn_vars.fn[i], nil)) and fn {
          content = content.replace(fn_vars[0][i], fn(), false)
        }
      }
    }
    
    # strip function escapes
    return content.replace('%{\x01!', '{!', false)
  }

  _replace_vars(content, variables, error) {
    # prepare
    content = content.replace('%{{', '%{\x01{')
    # replace variables: {{var_name}}
    # 
    # NOTE: This must come last as previous actions could generate or 
    # contain variables as well.
    var var_vars = content.matches(_var_regex)
    if var_vars {
      # var_vars = json.decode(json.encode(var_vars))
      iter var i = 0; i < var_vars.variable.length(); i++ {
        content = content.replace(var_vars[0][i], to_string(self._extract_var(variables, var_vars.variable[i], error)), false)
      }
    }
    
    # strip variable escapes
    return self._replace_funcs(content.replace('%{\x01{', '{{', false), error)
  }

  _process(path, element, variables) {
    if !element return nil
  
    def error(message) {
      if !is_string(element) and !is_list(element) {
        die Exception('${message} at ${path}[${element.position.start.line},${element.position.start.column}]')
      } else {
        die Exception(message)
      }
    }
  
    if is_string(element) {
      return self._replace_vars(element, variables, error)
    }
  
    if is_list(element) {
      return iters.map(element, | el | {
        return self._process(path, el, variables)
      }).compact()
    }
    
    if element.type == 'text' {
      # replace variables: {{var_name}}
      element.content = self._process(path, element.content, variables)
      return element
    } else {
      var attrs = self._get_attrs(element.attributes)
  
      if element {

        # process elements
        if element.tagName == 'include' {
          if !attrs or !attrs.contains('path')
            error('missing "path" attribute for include tag')
  
          var includePath = os.join_paths(self._root_dir, attrs.path)
          if !includePath.match('/[.][a-zA-Z]+$/') includePath += '.html'
          var fl = file(includePath)
          if fl.exists() {
            element = self._process(includePath, cocoa.decode(self._strip(fl.read()), {includePositions: true}), variables)
          } else {
            error('wire "${attrs.path}" not found')
          }
        } else if self._elements.contains(element.tagName) {
          # process custom elements
          var processed = self._elements[element.tagName](self, element)
          if processed {
            if !is_string(processed)
              error('invalid return when processing "${element.tagName}" tag')
            element = self._process(path, cocoa.decode(self._strip(processed), {includePositions: true}), variables)
          } else {
            element = nil
          }
        }
      }
  
      # process directives
      if attrs.contains(_if_drc) {
        # if tag
        var _var = self._extract_var(variables, attrs.get(_if_drc), error)
        if _var {
          self._strip_attr(element, _if_drc)
          element = self._process(path, element, variables)
        } else {
          element = nil
        }
      } else if attrs.contains(_not_drc) {
        # if not tag
        var _var = self._extract_var(variables, attrs.get(_not_drc), error)
        if !_var {
          self._strip_attr(element, _not_drc)
          element = self._process(path, element, variables)
        } else {
          element = nil
        }
      } else if attrs.contains(_for_drc) {
        # for tag
        if !attrs or !attrs.contains(_key_drc)
          error('missing "${_key_drc}" attribute for `${_for_drc}` attr')
        
        var data = self._extract_var(variables, attrs.get(_for_drc), error),
            key_name = attrs.get(_key_drc),
            value_name = attrs.get(_value_drc, nil)
  
        self._strip_attr(element, _for_drc, _key_drc, _value_drc)
        var for_vars = variables.clone()
  
        var result = []
        for key, value in data {
          for_vars.set('${key_name}', value_name ? key : value)
          if value_name for_vars.set('${value_name}', value)
          result.append(self._process(path, json.decode(json.encode(element)), for_vars))
        }
        return result
      }
      
      if element and element.contains('children') and element.children {
        element.children = self._process(path, element.children, variables)
      }
  
      # replace attribute variables...
      if element and !is_list(element) {
        for attr in element.attributes {
          if attr.value {
            # replace variables: {var_name}
            attr.value = self._process(path, attr.value, variables)
          }
        }
      }
  
      return element
    }
  }

  render(name, variables) {
    if !is_string(name)
      die Exception('wire name expected')
  
    var path = os.join_paths(self._root_dir, name)
    if !path.match('/[.][a-z0-9]+$/i') path += '.html'
  
    if variables != nil and !is_dict(variables)
      die Exception('variables must be passed to render() as a dictionary')
    if variables == nil variables = {}
  
    var wire_file = file(path)
    if wire_file.exists() {
      var file_content = self._strip(wire_file.read())
  
      return cocoa.encode(
        self._process(
          path,
          cocoa.decode(file_content, {includePositions: true}),
          variables
        )
      )
    }
  
    die Exception('wire "${name}" not found')
  }
}
