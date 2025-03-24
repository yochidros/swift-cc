swift-cc: main.swift
	swiftc main.swift -o swift-cc

test: swift-cc
	./test.sh

clean:
	rm -f swift-cc *.o *.s *~ tmp*

.PHONY: test clean
