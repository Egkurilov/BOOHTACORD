package registrationwelcome

import (
	"crypto/rand"
	"io"
	"math/big"
)

type Phrase struct{ ID, Body string }

var phrases = []Phrase{
	{"critical_success", "Критический успех! В гильдии новый участник."},
	{"new_adventure", "Новая глава приключения начинается здесь."},
	{"party_ready", "Команда стала сильнее. Добро пожаловать!"},
	{"quest_accepted", "Задание принято: найти друзей и хорошо провести время."},
	{"campfire", "У костра нашлось ещё одно место."},
	{"inventory", "Инвентарь пополнен хорошим настроением."},
	{"level_one", "Первый уровень пройден: регистрация завершена."},
	{"portal", "Портал открыт. Добро пожаловать в гильдию!"},
	{"achievement", "Достижение разблокировано: присоединиться к гильдии."},
	{"dice", "Кубики брошены — впереди новые встречи."},
}

func SelectPhrase(reader io.Reader) (Phrase, error) {
	if reader == nil {
		reader = rand.Reader
	}
	index, err := rand.Int(reader, big.NewInt(int64(len(phrases))))
	if err != nil {
		return Phrase{}, err
	}
	return phrases[index.Int64()], nil
}
