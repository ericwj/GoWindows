### Command line app `api` invokes Go stdlib functions

Input & Output definitions. Convert input to JSON; send via stdin.
```
type tInput struct {
   Api string
   Path string
}

type tOutput struct {
   Error string `json:",omitempty"`
   Errno int
   Result interface{}
   Name string `json:",omitempty"`
}
```

If `.Errno != 0` then `.Error` appears with the Go error message.

### Examples (Unix syntax)

```
$ echo '{"api":"path.filepath.Abs", "path":"../z"}' | ./api
{"Errno":0,"Result":"/.../z"}

$ echo '{"api":"path.filepath.IsAbs", "path":"../z"}' | ./api
{"Errno":0,"Result":false}

$ echo '{"api":"path.filepath.Walk", "path":"../z"}' | ./api
{"Errno":0,"Result":"../z","Name":"z"}
{"Errno":0,"Result":"../z/api","Name":"api"}
```
