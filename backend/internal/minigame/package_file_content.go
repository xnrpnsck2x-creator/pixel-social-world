package minigame

import (
	"encoding/base64"
	"errors"
)

func packageFileContentBytes(file PackageFile) ([]byte, bool, error) {
	if file.ContentBase64 != "" {
		bytes, err := base64.StdEncoding.DecodeString(file.ContentBase64)
		if err != nil {
			return nil, true, errors.New("content_base64_invalid:" + file.Path)
		}
		return bytes, true, nil
	}
	if file.ContentText != "" {
		return []byte(file.ContentText), true, nil
	}
	return nil, false, nil
}

func packageFileContentSize(file PackageFile) int64 {
	if bytes, ok, err := packageFileContentBytes(file); ok && err == nil {
		return int64(len(bytes))
	}
	return 0
}
