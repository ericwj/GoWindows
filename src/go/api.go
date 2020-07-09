package main

import (
   "path/filepath"
   "fmt"
   "io"
   "encoding/json"
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
var sJsonIn = json.NewDecoder(os.Stdin)

func main() {
   for {
      var aIn tInput
      err := sJsonIn.Decode(&aIn)
      if err != nil {
         if err != io.EOF { quit(err) }
         os.Exit(0)
      }
      var aOut tOutput

      switch aIn.Api {
      case "path.filepath.IsAbs":
         aOut.Result = filepath.IsAbs(aIn.Path)
      case "path.filepath.Abs":
         aOut.Result, err = filepath.Abs(aIn.Path)
      case "path.filepath.Walk":
         err = filepath.Walk(aIn.Path, walkInfo)
         if err != nil { quit(err) }
         continue
      default:
         quit(fmt.Errorf("Api not supported\n"))
      }
      if err != nil {
         setError(&aOut, err)
      }
      err = sJsonOut.Encode(aOut)
      if err != nil { quit(err) }
   }
}

func walkInfo(iPath string, iFi os.FileInfo, iErr error) error {
   aOut := tOutput{Result: iPath}
   if iFi != nil {
      aOut.Name = iFi.Name()
   }
   if iErr != nil {
      setError(&aOut, iErr)
   }
   err := sJsonOut.Encode(aOut)
   return err
}

func setError(iOut *tOutput, iErr error) {
   iOut.Error = iErr.Error()
   switch aV := iErr.(type) {
   case syscall.Errno: iOut.Errno = int(aV)
   case *os.PathError: iOut.Errno = int(aV.Err.(syscall.Errno))
   default:            iOut.Errno = -111
   }
}

func quit(i error) {
   fmt.Fprintf(os.Stderr, "%v\n", i)
   os.Exit(1)
}
