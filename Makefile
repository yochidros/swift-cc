swift-cc: main.swift
	swiftc main.swift -o swift-cc

test: swift-cc
	./test.sh

object: main.swift
	swiftc -emit-object main.swift -o main.o

clean:
	rm -f swift-cc *.o *.s *~ tmp*

.PHONY: test clean
