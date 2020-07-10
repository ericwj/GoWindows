// +build windows

package main

import (
   "os/exec"
   "fmt"
   "os"
   "testing"
)

const kPath = "dir"
var kArgs = []string{"."} // args in separate strings
   // re quoting, see https://golang.org/pkg/os/exec/#Command

func TestScript(i *testing.T) {
   aCmd := exec.Command(kPath, kArgs...)
   aCmd.Stdin, aCmd.Stdout, aCmd.Stderr = os.Stdin, os.Stdout, os.Stderr
   err := aCmd.Run()
   if err != nil {
      fmt.Fprintf(os.Stderr, "%v\n", err)
      i.Fail()
   }
}
