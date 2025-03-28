build:
	@swift build
	ln -sF .build/debug/SwiftCC ./swift-cc

run: swift-cc
	.build/debug/SwiftCC $(ARGS)

test: swift-cc
	./test.sh

clean:
	rm -rf .build *.o *.s *~ tmp* ./swift-cc

.PHONY: test clean
