### Command line app `api` invokes Go stdlib functions

Input & Output definitions. Convert input to JSON; send via stdin.
```
type tInput struct {
   Api string
   Path string
   Path2 string   // filepath.Rel
   Pattern string // filepath.Glob & .Match
   Join []string  // filepath.Join
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
$ echo '{"api":"filepath.Abs", "path":"../z"}' | ./api
{"Errno":0,"Result":"/.../z"}

$ echo '{"api":"filepath.IsAbs", "path":"../z"}' | ./api
{"Errno":0,"Result":false}

$ echo '{"api":"filepath.Walk", "path":"../z"}' | ./api
{"Errno":0,"Result":"../z","Name":"z"}
{"Errno":0,"Result":"../z/api","Name":"api"}
```
