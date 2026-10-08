package searchmessagesapi

import "net/http"

type filters struct {
	authorID                   string
	createdFrom, createdBefore string
	hasAttachment              *bool
}

func parseFilters(request *http.Request) (filters, bool) {
	authorID, authorOK := single(request, "author_id")
	attachment, attachmentOK := single(request, "has_attachment")
	from, fromOK := single(request, "created_from")
	before, beforeOK := single(request, "created_before")
	if !authorOK || !attachmentOK || !fromOK || !beforeOK ||
		(request.URL.Query().Has("author_id") && authorID == "") ||
		(request.URL.Query().Has("created_from") && from == "") ||
		(request.URL.Query().Has("created_before") && before == "") {
		return filters{}, false
	}
	result := filters{authorID: authorID, createdFrom: from, createdBefore: before}
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
