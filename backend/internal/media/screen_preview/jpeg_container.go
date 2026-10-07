package screenpreview

func validateJPEGContainer(body []byte) bool {
	if len(body) < 4 || body[0] != 0xff || body[1] != 0xd8 {
		return false
	}
	position, marker, scans := 2, byte(0), 0
	for {
		if marker == 0 {
			if position >= len(body) || body[position] != 0xff {
				return false
			}
			for position < len(body) && body[position] == 0xff {
				position++
			}
			if position >= len(body) {
				return false
			}
			marker, position = body[position], position+1
		}
		if marker == 0xd9 {
			return scans > 0 && position == len(body)
		}
		if marker == 0xd8 || marker == 0x00 || marker >= 0xd0 && marker <= 0xd7 {
			return false
		}
		if marker == 0x01 {
			marker = 0
			continue
		}
		if position+2 > len(body) {
			return false
		}
		segmentLength := int(body[position])<<8 | int(body[position+1])
		if segmentLength < 2 || position+segmentLength > len(body) {
			return false
		}
		position += segmentLength
		if marker != 0xda {
			marker = 0
			continue
		}
		scans++
		marker = 0
		for position < len(body) {
			if body[position] != 0xff {
				position++
				continue
			}
			markerStart := position
			for position < len(body) && body[position] == 0xff {
				position++
			}
			if position >= len(body) {
				return false
			}
			code := body[position]
			position++
			if code == 0x00 || code >= 0xd0 && code <= 0xd7 {
				continue
			}
			marker, position = code, position
			if marker == 0xd9 {
				return position == len(body)
			}
			if marker == 0xd8 || marker == 0x01 {
				return false
			}
			if markerStart < 2 {
				return false
			}
			break
		}
		if marker == 0 {
			return false
		}
	}
}
