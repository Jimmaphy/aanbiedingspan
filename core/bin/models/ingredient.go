package models

type Ingredient struct {
	IngredientId int32
	Name         string
	History      string
	Usage        string
	Storage      string
	Link         *string
	ImageId      int64
}
