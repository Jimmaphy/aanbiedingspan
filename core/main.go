package main

import "os"

func main() {
	apiCmd := "serve"
	termArgs := os.Args

	if len(termArgs) > 1 && termArgs[1] == apiCmd {
		// Code for API
	} else {
		// Code for CMD
	}
}
