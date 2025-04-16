build:
	@swift build > /dev/null
	@ln -sF .build/debug/SwiftCC ./swift-cc

build-v:
	@swift build
	@ln -sF .build/debug/SwiftCC ./swift-cc

bin:
	cc -o main tmp.s

debug: build
	@./swift-cc $(ARGS) > tmp.s
	@cat tmp.s
	@make bin
	./main

run: swift-cc
	.build/debug/SwiftCC $(ARGS)

test: build
	@sh ./test.sh

clean:
	rm -rf .build *.o *.s *~ tmp* *.c ./swift-cc

.PHONY: test clean
