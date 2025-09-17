package models

type Recipe struct {
	RecipeId           int64
	SourceId           [4]rune
	Name               string
	Url                string
	Description        string
	Time               int32
	Portions           int32
	RecipeDifficultyId int8
	ImageId            int64
}
