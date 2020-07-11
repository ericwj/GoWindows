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
      case "os.Getwd":               aOut.Result, err = os.Getwd()
      case "os.Chdir":               err = os.Chdir(aIn.Path)
      case "filepath.Separator":     aOut.Result = string(filepath.Separator)
      case "filepath.ListSeparator": aOut.Result = string(filepath.ListSeparator)
      case "filepath.Abs":           aOut.Result, err = filepath.Abs(aIn.Path)
      case "filepath.EvalSymlinks":  aOut.Result, err = filepath.EvalSymlinks(aIn.Path)
      case "filepath.Glob":          aOut.Result, err = filepath.Glob(aIn.Pattern)
      case "filepath.Match":         aOut.Result, err = filepath.Match(aIn.Pattern, aIn.Path)
      case "filepath.Rel":           aOut.Result, err = filepath.Rel(aIn.Path, aIn.Path2)
      case "filepath.Base":          aOut.Result = filepath.Base(aIn.Path)
      case "filepath.Clean":         aOut.Result = filepath.Clean(aIn.Path)
      case "filepath.Dir":           aOut.Result = filepath.Dir(aIn.Path)
      case "filepath.Ext":           aOut.Result = filepath.Ext(aIn.Path)
      case "filepath.FromSlash":     aOut.Result = filepath.FromSlash(aIn.Path)
      case "filepath.IsAbs":         aOut.Result = filepath.IsAbs(aIn.Path)
      case "filepath.Join":          aOut.Result = filepath.Join(aIn.Join...)
      case "filepath.SplitList":     aOut.Result = filepath.SplitList(aIn.Path)
      case "filepath.ToSlash":       aOut.Result = filepath.ToSlash(aIn.Path)
      case "filepath.VolumeName":    aOut.Result = filepath.VolumeName(aIn.Path)
      case "filepath.Split":         aOut.Result, aOut.Name = filepath.Split(aIn.Path)
      case "filepath.Walk":
         err = filepath.Walk(aIn.Path, walkInfo)
         if err != nil { quit(err) }
         continue
      default:
         quit(fmt.Errorf("Api not supported: %s\n", aIn.Api))
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
