
.PHONY: clean release

VERSION=31
NAME=FriendsShare

clean:
	gfind . -name '*~' -print -delete

release: clean
	git branch v$(VERSION)
	git checkout v$(VERSION)
	rm -f $(NAME)-$(VERSION).zip
	find $(NAME)					\
		-name .git -prune -o			\
		-name Makefile -prune -o		\
		-name '.*.swp' -prune -o		\
		-print > files.txt
	zip -@ $(NAME)-$(VERSION).zip < files.txt
	rm -f files.txt
	git add $(NAME)-$(VERSION).zip
	git commit -m v$(VERSION) $(NAME)-$(VERSION).zip
	git tag -m v$(VERSION) -a v$(VERSION)
	git checkout master
	git branch -D v$(VERSION)
	@echo
	@echo "Now push the new tag with"
	@echo "git push --tags"
	@echo
