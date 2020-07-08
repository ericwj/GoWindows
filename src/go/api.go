package main

import (
   "encoding/json"
   "path/filepath"
   "fmt"
   "os"
   "syscall"
)

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

var sJsonOut = json.NewEncoder(os.Stdout)

func main() {
   var aIn tInput
   err := json.NewDecoder(os.Stdin).Decode(&aIn)
   if err != nil { quit(err) }
   var aOut tOutput

   switch aIn.Api {
   case "path.filepath.IsAbs":
      aOut.Result = filepath.IsAbs(aIn.Path)
   case "path.filepath.Abs":
      aOut.Result, err = filepath.Abs(aIn.Path)
   case "path.filepath.Walk":
      err = filepath.Walk(aIn.Path, walkInfo)
      if err != nil { quit(err) }
      os.Exit(0)
   default:
      fmt.Fprintf(os.Stderr, "Api not supported\n")
      os.Exit(1)
   }
   if err != nil {
      aOut.Error = err.Error()
      switch aV := err.(type) {
      case syscall.Errno: aOut.Errno = int(aV)
      case *os.PathError: aOut.Errno = int(aV.Err.(syscall.Errno))
      default:            aOut.Errno = -111
      }
   }
   err = sJsonOut.Encode(aOut)
   if err != nil { quit(err) }
   os.Exit(0)
}

func walkInfo(iPath string, iFi os.FileInfo, iErr error) error {
   aOut := tOutput{Result: iPath, Name: iFi.Name()}
   if iErr != nil {
      aOut.Error, aOut.Errno = iErr.Error(), -222
   }
   err := sJsonOut.Encode(aOut)
   return err
}

func quit(i error) {
   fmt.Fprintf(os.Stderr, "%v\n", i)
   os.Exit(1)
}
