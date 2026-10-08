package searchmessagesapi

import "net/http"

type filters struct {
	authorID      string
	hasAttachment *bool
}

func parseFilters(request *http.Request) (filters, bool) {
	authorID, authorOK := single(request, "author_id")
	attachment, attachmentOK := single(request, "has_attachment")
	if !authorOK || !attachmentOK || (request.URL.Query().Has("author_id") && authorID == "") {
		return filters{}, false
	}
	result := filters{authorID: authorID}
	if !request.URL.Query().Has("has_attachment") {
		return result, true
	}
	value := false
	switch attachment {
	case "true":
		value = true
	case "false":
	default:
		return filters{}, false
	}
	result.hasAttachment = &value
	return result, true
}
