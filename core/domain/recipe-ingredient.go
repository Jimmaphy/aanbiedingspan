package models

type RecipeIngredient struct {
	RecipeId     int64
	IngredientId int64
	Measurement  float32
	UnitId       int16
}
