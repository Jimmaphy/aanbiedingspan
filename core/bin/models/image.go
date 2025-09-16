package models

type Image struct {
	ImageId         int64
	ImageCategoryId [2]rune
	Filename        string
	AltText         string
	OriginalWidth   int32
	OriginalHeight  int32
}
