package api

import "juku-library-db/internal/store"

type Drama = store.Drama
type SortMetadata = store.SortMetadata
type MemoryStore = store.Memory

func NewMemoryStore() store.Store { return store.NewMemory() }
