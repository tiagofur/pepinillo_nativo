package domain

type SubTask struct {
	ID         int     `json:"id" gorm:"primaryKey;autoIncrement"`
	TaskID     int     `json:"taskId" gorm:"index;not null"`
	Title      *string `json:"title"`
	IsFinished bool    `json:"isFinished" gorm:"default:false;not null"`
}

func (SubTask) TableName() string {
	return "subtasks"
}
