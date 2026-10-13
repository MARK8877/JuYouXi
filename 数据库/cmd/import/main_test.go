package main

import "testing"

func TestDecodeDramasAcceptsArrayAndAPIEnvelope(t *testing.T) {
	for _, input := range []string{
		`[{"id":"hongguo:1","title":"一"}]`,
		`{"data":[{"id":"hongguo:2","title":"二"}]}`,
	} {
		dramas, err := decodeDramas([]byte(input))
		if err != nil || len(dramas) != 1 || dramas[0].ID == "" {
			t.Fatalf("decode %s = %#v, %v", input, dramas, err)
		}
	}
}
