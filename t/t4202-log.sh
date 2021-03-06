#!/bin/sh

test_description='git log'

. ./test-lib.sh
. "$TEST_DIRECTORY/lib-gpg.sh"
. "$TEST_DIRECTORY/lib-terminal.sh"

test_expect_success setup '

	echo one >one &&
	git add one &&
	test_tick &&
	git commit -m initial &&

	echo ichi >one &&
	git add one &&
	test_tick &&
	git commit -m second &&

	git mv one ichi &&
	test_tick &&
	git commit -m third &&

	cp ichi ein &&
	git add ein &&
	test_tick &&
	git commit -m fourth &&

	mkdir a &&
	echo ni >a/two &&
	git add a/two &&
	test_tick &&
	git commit -m fifth  &&

	git rm a/two &&
	test_tick &&
	git commit -m sixth

'

printf "sixth\nfifth\nfourth\nthird\nsecond\ninitial" > expect
test_expect_success 'pretty' '

	git log --pretty="format:%s" > actual &&
	test_cmp expect actual
'

printf "sixth\nfifth\nfourth\nthird\nsecond\ninitial\n" > expect
test_expect_success 'pretty (tformat)' '

	git log --pretty="tformat:%s" > actual &&
	test_cmp expect actual
'

test_expect_success 'pretty (shortcut)' '

	git log --pretty="%s" > actual &&
	test_cmp expect actual
'

test_expect_success 'format' '

	git log --format="%s" > actual &&
	test_cmp expect actual
'

cat > expect << EOF
 This is
  the sixth
  commit.
 This is
  the fifth
  commit.
EOF

test_expect_success 'format %w(11,1,2)' '

	git log -2 --format="%w(11,1,2)This is the %s commit." > actual &&
	test_cmp expect actual
'

test_expect_success 'format %w(,1,2)' '

	git log -2 --format="%w(,1,2)This is%nthe %s%ncommit." > actual &&
	test_cmp expect actual
'

cat > expect << EOF
804a787 sixth
394ef78 fifth
5d31159 fourth
2fbe8c0 third
f7dab8e second
3a2fdcb initial
EOF
test_expect_success 'oneline' '

	git log --oneline > actual &&
	test_cmp expect actual
'

test_expect_success 'diff-filter=A' '

	git log --no-renames --pretty="format:%s" --diff-filter=A HEAD > actual &&
	git log --no-renames --pretty="format:%s" --diff-filter A HEAD > actual-separate &&
	printf "fifth\nfourth\nthird\ninitial" > expect &&
	test_cmp expect actual &&
	test_cmp expect actual-separate

'

test_expect_success 'diff-filter=M' '

	actual=$(git log --pretty="format:%s" --diff-filter=M HEAD) &&
	expect=$(echo second) &&
	verbose test "$actual" = "$expect"

'

test_expect_success 'diff-filter=D' '

	actual=$(git log --no-renames --pretty="format:%s" --diff-filter=D HEAD) &&
	expect=$(echo sixth ; echo third) &&
	verbose test "$actual" = "$expect"

'

test_expect_success 'diff-filter=R' '

	actual=$(git log -M --pretty="format:%s" --diff-filter=R HEAD) &&
	expect=$(echo third) &&
	verbose test "$actual" = "$expect"

'

test_expect_success 'diff-filter=C' '

	actual=$(git log -C -C --pretty="format:%s" --diff-filter=C HEAD) &&
	expect=$(echo fourth) &&
	verbose test "$actual" = "$expect"

'

test_expect_success 'git log --follow' '

	actual=$(git log --follow --pretty="format:%s" ichi) &&
	expect=$(echo third ; echo second ; echo initial) &&
	verbose test "$actual" = "$expect"
'

test_expect_success 'git config log.follow works like --follow' '
	test_config log.follow true &&
	actual=$(git log --pretty="format:%s" ichi) &&
	expect=$(echo third ; echo second ; echo initial) &&
	verbose test "$actual" = "$expect"
'

test_expect_success 'git config log.follow does not die with multiple paths' '
	test_config log.follow true &&
	git log --pretty="format:%s" ichi ein
'

test_expect_success 'git config log.follow does not die with no paths' '
	test_config log.follow true &&
	git log --
'

test_expect_success 'git config log.follow is overridden by --no-follow' '
	test_config log.follow true &&
	actual=$(git log --no-follow --pretty="format:%s" ichi) &&
	expect="third" &&
	verbose test "$actual" = "$expect"
'

cat > expect << EOF
804a787 sixth
394ef78 fifth
5d31159 fourth
EOF
test_expect_success 'git log --no-walk <commits> sorts by commit time' '
	git log --no-walk --oneline 5d31159 804a787 394ef78 > actual &&
	test_cmp expect actual
'

test_expect_success 'git log --no-walk=sorted <commits> sorts by commit time' '
	git log --no-walk=sorted --oneline 5d31159 804a787 394ef78 > actual &&
	test_cmp expect actual
'

cat > expect << EOF
=== 804a787 sixth
=== 394ef78 fifth
=== 5d31159 fourth
EOF
test_expect_success 'git log --line-prefix="=== " --no-walk <commits> sorts by commit time' '
	git log --line-prefix="=== " --no-walk --oneline 5d31159 804a787 394ef78 > actual &&
	test_cmp expect actual
'

cat > expect << EOF
5d31159 fourth
804a787 sixth
394ef78 fifth
EOF
test_expect_success 'git log --no-walk=unsorted <commits> leaves list of commits as given' '
	git log --no-walk=unsorted --oneline 5d31159 804a787 394ef78 > actual &&
	test_cmp expect actual
'

test_expect_success 'git show <commits> leaves list of commits as given' '
	git show --oneline -s 5d31159 804a787 394ef78 > actual &&
	test_cmp expect actual
'

test_expect_success 'setup case sensitivity tests' '
	echo case >one &&
	test_tick &&
	git add one &&
	git commit -a -m Second
'

test_expect_success 'log --grep' '
	echo second >expect &&
	git log -1 --pretty="tformat:%s" --grep=sec >actual &&
	test_cmp expect actual
'

cat > expect << EOF
second
initial
EOF
test_expect_success 'log --invert-grep --grep' '
	# Fixed
	git -c grep.patternType=fixed log --pretty="tformat:%s" --invert-grep --grep=th --grep=Sec >actual &&
	test_cmp expect actual &&

	# POSIX basic
	git -c grep.patternType=basic log --pretty="tformat:%s" --invert-grep --grep=t[h] --grep=S[e]c >actual &&
	test_cmp expect actual &&

	# POSIX extended
	git -c grep.patternType=basic log --pretty="tformat:%s" --invert-grep --grep=t[h] --grep=S[e]c >actual &&
	test_cmp expect actual &&

	# PCRE
	if test_have_prereq PCRE
	then
		git -c grep.patternType=perl log --pretty="tformat:%s" --invert-grep --grep=t[h] --grep=S[e]c >actual &&
		test_cmp expect actual
	fi
'

test_expect_success 'log --invert-grep --grep -i' '
	echo initial >expect &&

	# Fixed
	git -c grep.patternType=fixed log --pretty="tformat:%s" --invert-grep -i --grep=th --grep=Sec >actual &&
	test_cmp expect actual &&

	# POSIX basic
	git -c grep.patternType=basic log --pretty="tformat:%s" --invert-grep -i --grep=t[h] --grep=S[e]c >actual &&
	test_cmp expect actual &&

	# POSIX extended
	git -c grep.patternType=extended log --pretty="tformat:%s" --invert-grep -i --grep=t[h] --grep=S[e]c >actual &&
	test_cmp expect actual &&

	# PCRE
	if test_have_prereq PCRE
	then
		git -c grep.patternType=perl log --pretty="tformat:%s" --invert-grep -i --grep=t[h] --grep=S[e]c >actual &&
		test_cmp expect actual
	fi
'

test_expect_success 'log --grep option parsing' '
	echo second >expect &&
	git log -1 --pretty="tformat:%s" --grep sec >actual &&
	test_cmp expect actual &&
	test_must_fail git log -1 --pretty="tformat:%s" --grep
'

test_expect_success 'log -i --grep' '
	echo Second >expect &&
	git log -1 --pretty="tformat:%s" -i --grep=sec >actual &&
	test_cmp expect actual
'

test_expect_success 'log --grep -i' '
	echo Second >expect &&

	# Fixed
	git log -1 --pretty="tformat:%s" --grep=sec -i >actual &&
	test_cmp expect actual &&

	# POSIX basic
	git -c grep.patternType=basic log -1 --pretty="tformat:%s" --grep=s[e]c -i >actual &&
	test_cmp expect actual &&

	# POSIX extended
	git -c grep.patternType=extended log -1 --pretty="tformat:%s" --grep=s[e]c -i >actual &&
	test_cmp expect actual &&

	# PCRE
	if test_have_prereq PCRE
	then
		git -c grep.patternType=perl log -1 --pretty="tformat:%s" --grep=s[e]c -i >actual &&
		test_cmp expect actual
	fi
'

test_expect_success 'log -F -E --grep=<ere> uses ere' '
	echo second >expect &&
	# basic would need \(s\) to do the same
	git log -1 --pretty="tformat:%s" -F -E --grep="(s).c.nd" >actual &&
	test_cmp expect actual
'

test_expect_success PCRE 'log -F -E --perl-regexp --grep=<pcre> uses PCRE' '
	test_when_finished "rm -rf num_commits" &&
	git init num_commits &&
	(
		cd num_commits &&
		test_commit 1d &&
		test_commit 2e
	) &&

	# In PCRE \d in [\d] is like saying "0-9", and matches the 2
	# in 2e...
	echo 2e >expect &&
	git -C num_commits log -1 --pretty="tformat:%s" -F -E --perl-regexp --grep="[\d]" >actual &&
	test_cmp expect actual &&

	# ...in POSIX basic and extended it is the same as [d],
	# i.e. "d", which matches 1d, but does not match 2e.
	echo 1d >expect &&
	git -C num_commits log -1 --pretty="tformat:%s" -F -E --grep="[\d]" >actual &&
	test_cmp expect actual
'

test_expect_success 'log with grep.patternType configuration' '
	>expect &&
	git -c grep.patterntype=fixed \
	log -1 --pretty=tformat:%s --grep=s.c.nd >actual &&
	test_cmp expect actual
'

test_expect_success 'log with grep.patternType configuration and command line' '
	echo second >expect &&
	git -c grep.patterntype=fixed \
	log -1 --pretty=tformat:%s --basic-regexp --grep=s.c.nd >actual &&
	test_cmp expect actual
'

test_expect_success 'log with various grep.patternType configurations & command-lines' '
	git init pattern-type &&
	(
		cd pattern-type &&
		test_commit 1 file A &&

		# The tagname is overridden here because creating a
		# tag called "(1|2)" as test_commit would otherwise
		# implicitly do would fail on e.g. MINGW.
		test_commit "(1|2)" file B 2 &&

		echo "(1|2)" >expect.fixed &&
		cp expect.fixed expect.basic &&
		cp expect.fixed expect.extended &&
		cp expect.fixed expect.perl &&

		# A strcmp-like match with fixed.
		git -c grep.patternType=fixed log --pretty=tformat:%s \
			--grep="(1|2)" >actual.fixed &&

		# POSIX basic matches (, | and ) literally.
		git -c grep.patternType=basic log --pretty=tformat:%s \
			--grep="(.|.)" >actual.basic &&

		# POSIX extended needs to have | escaped to match it
		# literally, whereas under basic this is the same as
		# (|2), i.e. it would also match "1". This test checks
		# for extended by asserting that it is not matching
		# what basic would match.
		git -c grep.patternType=extended log --pretty=tformat:%s \
			--grep="\|2" >actual.extended &&
		if test_have_prereq PCRE
		then
			# Only PCRE would match [\d]\| with only
			# "(1|2)" due to [\d]. POSIX basic would match
			# both it and "1" since similarly to the
			# extended match above it is the same as
			# \([\d]\|\). POSIX extended would
			# match neither.
			git -c grep.patternType=perl log --pretty=tformat:%s \
				--grep="[\d]\|" >actual.perl &&
			test_cmp expect.perl actual.perl
		fi &&
		test_cmp expect.fixed actual.fixed &&
		test_cmp expect.basic actual.basic &&
		test_cmp expect.extended actual.extended &&

		git log --pretty=tformat:%s -F \
			--grep="(1|2)" >actual.fixed.short-arg &&
		git log --pretty=tformat:%s -E \
			--grep="\|2" >actual.extended.short-arg &&
		if test_have_prereq PCRE
		then
			git log --pretty=tformat:%s -P \
				--grep="[\d]\|" >actual.perl.short-arg
		else
			test_must_fail git log -P \
				--grep="[\d]\|"
		fi &&
		test_cmp expect.fixed actual.fixed.short-arg &&
		test_cmp expect.extended actual.extended.short-arg &&
		if test_have_prereq PCRE
		then
			test_cmp expect.perl actual.perl.short-arg
		fi &&

		git log --pretty=tformat:%s --fixed-strings \
			--grep="(1|2)" >actual.fixed.long-arg &&
		git log --pretty=tformat:%s --basic-regexp \
			--grep="(.|.)" >actual.basic.long-arg &&
		git log --pretty=tformat:%s --extended-regexp \
			--grep="\|2" >actual.extended.long-arg &&
		if test_have_prereq PCRE
		then
			git log --pretty=tformat:%s --perl-regexp \
				--grep="[\d]\|" >actual.perl.long-arg &&
			test_cmp expect.perl actual.perl.long-arg
		else
			test_must_fail git log --perl-regexp \
				--grep="[\d]\|"
		fi &&
		test_cmp expect.fixed actual.fixed.long-arg &&
		test_cmp expect.basic actual.basic.long-arg &&
		test_cmp expect.extended actual.extended.long-arg
	)
'

cat > expect <<EOF
* Second
* sixth
* fifth
* fourth
* third
* second
* initial
EOF

test_expect_success 'simple log --graph' '
	git log --graph --pretty=tformat:%s >actual &&
	test_cmp expect actual
'

cat > expect <<EOF
123 * Second
123 * sixth
123 * fifth
123 * fourth
123 * third
123 * second
123 * initial
EOF

test_expect_success 'simple log --graph --line-prefix="123 "' '
	git log --graph --line-prefix="123 " --pretty=tformat:%s >actual &&
	test_cmp expect actual
'

test_expect_success 'set up merge history' '
	git checkout -b side HEAD~4 &&
	test_commit side-1 1 1 &&
	test_commit side-2 2 2 &&
	git checkout master &&
	git merge side
'

cat > expect <<\EOF
*   Merge branch 'side'
|\
| * side-2
| * side-1
* | Second
* | sixth
* | fifth
* | fourth
|/
* third
* second
* initial
EOF

test_expect_success 'log --graph with merge' '
	git log --graph --date-order --pretty=tformat:%s |
		sed "s/ *\$//" >actual &&
	test_cmp expect actual
'

cat > expect <<\EOF
| | | *   Merge branch 'side'
| | | |\
| | | | * side-2
| | | | * side-1
| | | * | Second
| | | * | sixth
| | | * | fifth
| | | * | fourth
| | | |/
| | | * third
| | | * second
| | | * initial
EOF

test_expect_success 'log --graph --line-prefix="| | | " with merge' '
	git log --line-prefix="| | | " --graph --date-order --pretty=tformat:%s |
		sed "s/ *\$//" >actual &&
	test_cmp expect actual
'

cat > expect.colors <<\EOF
*   Merge branch 'side'
<BLUE>|<RESET><CYAN>\<RESET>
<BLUE>|<RESET> * side-2
<BLUE>|<RESET> * side-1
* <CYAN>|<RESET> Second
* <CYAN>|<RESET> sixth
* <CYAN>|<RESET> fifth
* <CYAN>|<RESET> fourth
<CYAN>|<RESET><CYAN>/<RESET>
* third
* second
* initial
EOF

test_expect_success 'log --graph with merge with log.graphColors' '
	test_config log.graphColors " blue,invalid-color, cyan, red  , " &&
	git log --color=always --graph --date-order --pretty=tformat:%s |
		test_decode_color | sed "s/ *\$//" >actual &&
	test_cmp expect.colors actual
'

test_expect_success 'log --raw --graph -m with merge' '
	git log --raw --graph --oneline -m master | head -n 500 >actual &&
	grep "initial" actual
'

test_expect_success 'diff-tree --graph' '
	git diff-tree --graph master^ | head -n 500 >actual &&
	grep "one" actual
'

cat > expect <<\EOF
*   commit master
|\  Merge: A B
| | Author: A U Thor <author@example.com>
| |
| |     Merge branch 'side'
| |
| * commit tags/side-2
| | Author: A U Thor <author@example.com>
| |
| |     side-2
| |
| * commit tags/side-1
| | Author: A U Thor <author@example.com>
| |
| |     side-1
| |
* | commit master~1
| | Author: A U Thor <author@example.com>
| |
| |     Second
| |
* | commit master~2
| | Author: A U Thor <author@example.com>
| |
| |     sixth
| |
* | commit master~3
| | Author: A U Thor <author@example.com>
| |
| |     fifth
| |
* | commit master~4
|/  Author: A U Thor <author@example.com>
|
|       fourth
|
* commit tags/side-1~1
| Author: A U Thor <author@example.com>
|
|     third
|
* commit tags/side-1~2
| Author: A U Thor <author@example.com>
|
|     second
|
* commit tags/side-1~3
  Author: A U Thor <author@example.com>

      initial
EOF

test_expect_success 'log --graph with full output' '
	git log --graph --date-order --pretty=short |
		git name-rev --name-only --stdin |
		sed "s/Merge:.*/Merge: A B/;s/ *\$//" >actual &&
	test_cmp expect actual
'

test_expect_success 'set up more tangled history' '
	git checkout -b tangle HEAD~6 &&
	test_commit tangle-a tangle-a a &&
	git merge master~3 &&
	git merge side~1 &&
	git checkout master &&
	git merge tangle &&
	git checkout -b reach &&
	test_commit reach &&
	git checkout master &&
	git checkout -b octopus-a &&
	test_commit octopus-a &&
	git checkout master &&
	git checkout -b octopus-b &&
	test_commit octopus-b &&
	git checkout master &&
	test_commit seventh &&
	git merge octopus-a octopus-b &&
	git merge reach
'

cat > expect <<\EOF
*   Merge tag 'reach'
|\
| \
|  \
*-. \   Merge tags 'octopus-a' and 'octopus-b'
|\ \ \
* | | | seventh
| | * | octopus-b
| |/ /
|/| |
| * | octopus-a
|/ /
| * reach
|/
*   Merge branch 'tangle'
|\
| *   Merge branch 'side' (early part) into tangle
| |\
| * \   Merge branch 'master' (early part) into tangle
| |\ \
| * | | tangle-a
* | | |   Merge branch 'side'
|\ \ \ \
| * | | | side-2
| | |_|/
| |/| |
| * | | side-1
* | | | Second
* | | | sixth
| |_|/
|/| |
* | | fifth
* | | fourth
|/ /
* | third
|/
* second
* initial
EOF

test_expect_success 'log --graph with merge' '
	git log --graph --date-order --pretty=tformat:%s |
		sed "s/ *\$//" >actual &&
	test_cmp expect actual
'

test_expect_success 'log.decorate configuration' '
	git log --oneline --no-decorate >expect.none &&
	git log --oneline --decorate >expect.short &&
	git log --oneline --decorate=full >expect.full &&

	echo "[log] decorate" >>.git/config &&
	git log --oneline >actual &&
	test_cmp expect.short actual &&

	test_config log.decorate true &&
	git log --oneline >actual &&
	test_cmp expect.short actual &&
	git log --oneline --decorate=full >actual &&
	test_cmp expect.full actual &&
	git log --oneline --decorate=no >actual &&
	test_cmp expect.none actual &&

	test_config log.decorate no &&
	git log --oneline >actual &&
	test_cmp expect.none actual &&
	git log --oneline --decorate >actual &&
	test_cmp expect.short actual &&
	git log --oneline --decorate=full >actual &&
	test_cmp expect.full actual &&

	test_config log.decorate 1 &&
	git log --oneline >actual &&
	test_cmp expect.short actual &&
	git log --oneline --decorate=full >actual &&
	test_cmp expect.full actual &&
	git log --oneline --decorate=no >actual &&
	test_cmp expect.none actual &&

	test_config log.decorate short &&
	git log --oneline >actual &&
	test_cmp expect.short actual &&
	git log --oneline --no-decorate >actual &&
	test_cmp expect.none actual &&
	git log --oneline --decorate=full >actual &&
	test_cmp expect.full actual &&

	test_config log.decorate full &&
	git log --oneline >actual &&
	test_cmp expect.full actual &&
	git log --oneline --no-decorate >actual &&
	test_cmp expect.none actual &&
	git log --oneline --decorate >actual &&
	test_cmp expect.short actual &&

	test_unconfig log.decorate &&
	git log --pretty=raw >expect.raw &&
	test_config log.decorate full &&
	git log --pretty=raw >actual &&
	test_cmp expect.raw actual

'

test_expect_success 'decorate-refs with glob' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach
	Merge-tags-octopus-a-and-octopus-b
	seventh
	octopus-b (octopus-b)
	octopus-a (octopus-a)
	reach
	EOF
	git log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs="heads/octopus*" >actual &&
	test_cmp expect.decorate actual
'

test_expect_success 'decorate-refs without globs' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach
	Merge-tags-octopus-a-and-octopus-b
	seventh
	octopus-b
	octopus-a
	reach (tag: reach)
	EOF
	git log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs="tags/reach" >actual &&
	test_cmp expect.decorate actual
'

test_expect_success 'multiple decorate-refs' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach
	Merge-tags-octopus-a-and-octopus-b
	seventh
	octopus-b (octopus-b)
	octopus-a (octopus-a)
	reach (tag: reach)
	EOF
	git log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs="heads/octopus*" \
		--decorate-refs="tags/reach" >actual &&
    test_cmp expect.decorate actual
'

test_expect_success 'decorate-refs-exclude with glob' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach (HEAD -> master)
	Merge-tags-octopus-a-and-octopus-b
	seventh (tag: seventh)
	octopus-b (tag: octopus-b)
	octopus-a (tag: octopus-a)
	reach (tag: reach, reach)
	EOF
	git log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs-exclude="heads/octopus*" >actual &&
	test_cmp expect.decorate actual
'

test_expect_success 'decorate-refs-exclude without globs' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach (HEAD -> master)
	Merge-tags-octopus-a-and-octopus-b
	seventh (tag: seventh)
	octopus-b (tag: octopus-b, octopus-b)
	octopus-a (tag: octopus-a, octopus-a)
	reach (reach)
	EOF
	git log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs-exclude="tags/reach" >actual &&
	test_cmp expect.decorate actual
'

test_expect_success 'multiple decorate-refs-exclude' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach (HEAD -> master)
	Merge-tags-octopus-a-and-octopus-b
	seventh (tag: seventh)
	octopus-b (tag: octopus-b)
	octopus-a (tag: octopus-a)
	reach (reach)
	EOF
	git log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs-exclude="heads/octopus*" \
		--decorate-refs-exclude="tags/reach" >actual &&
	test_cmp expect.decorate actual
'

test_expect_success 'decorate-refs and decorate-refs-exclude' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach (master)
	Merge-tags-octopus-a-and-octopus-b
	seventh
	octopus-b
	octopus-a
	reach (reach)
	EOF
	git log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs="heads/*" \
		--decorate-refs-exclude="heads/oc*" >actual &&
	test_cmp expect.decorate actual
'

test_expect_success 'log.decorate config parsing' '
	git log --oneline --decorate=full >expect.full &&
	git log --oneline --decorate=short >expect.short &&

	test_config log.decorate full &&
	test_config log.mailmap true &&
	git log --oneline >actual &&
	test_cmp expect.full actual &&
	git log --oneline --decorate=short >actual &&
	test_cmp expect.short actual
'

test_expect_success TTY 'log output on a TTY' '
	git log --color --oneline --decorate >expect.short &&

	test_terminal git log --oneline >actual &&
	test_cmp expect.short actual
'

test_expect_success 'reflog is expected format' '
	git log -g --abbrev-commit --pretty=oneline >expect &&
	git reflog >actual &&
	test_cmp expect actual
'

test_expect_success 'whatchanged is expected format' '
	git log --no-merges --raw >expect &&
	git whatchanged >actual &&
	test_cmp expect actual
'

test_expect_success 'log.abbrevCommit configuration' '
	git log --abbrev-commit >expect.log.abbrev &&
	git log --no-abbrev-commit >expect.log.full &&
	git log --pretty=raw >expect.log.raw &&
	git reflog --abbrev-commit >expect.reflog.abbrev &&
	git reflog --no-abbrev-commit >expect.reflog.full &&
	git whatchanged --abbrev-commit >expect.whatchanged.abbrev &&
	git whatchanged --no-abbrev-commit >expect.whatchanged.full &&

	test_config log.abbrevCommit true &&

	git log >actual &&
	test_cmp expect.log.abbrev actual &&
	git log --no-abbrev-commit >actual &&
	test_cmp expect.log.full actual &&

	git log --pretty=raw >actual &&
	test_cmp expect.log.raw actual &&

	git reflog >actual &&
	test_cmp expect.reflog.abbrev actual &&
	git reflog --no-abbrev-commit >actual &&
	test_cmp expect.reflog.full actual &&

	git whatchanged >actual &&
	test_cmp expect.whatchanged.abbrev actual &&
	git whatchanged --no-abbrev-commit >actual &&
	test_cmp expect.whatchanged.full actual
'

test_expect_success 'show added path under "--follow -M"' '
	# This tests for a regression introduced in v1.7.2-rc0~103^2~2
	test_create_repo regression &&
	(
		cd regression &&
		test_commit needs-another-commit &&
		test_commit foo.bar &&
		git log -M --follow -p foo.bar.t &&
		git log -M --follow --stat foo.bar.t &&
		git log -M --follow --name-only foo.bar.t
	)
'

test_expect_success 'git log -c --follow' '
	test_create_repo follow-c &&
	(
		cd follow-c &&
		test_commit initial file original &&
		git rm file &&
		test_commit rename file2 original &&
		git reset --hard initial &&
		test_commit modify file foo &&
		git merge -m merge rename &&
		git log -c --follow file2
	)
'

cat >expect <<\EOF
*   commit COMMIT_OBJECT_NAME
|\  Merge: MERGE_PARENTS
| | Author: A U Thor <author@example.com>
| |
| |     Merge HEADS DESCRIPTION
| |
| * commit COMMIT_OBJECT_NAME
| | Author: A U Thor <author@example.com>
| |
| |     reach
| | ---
| |  reach.t | 1 +
| |  1 file changed, 1 insertion(+)
| |
| | diff --git a/reach.t b/reach.t
| | new file mode 100644
| | index 0000000..10c9591
| | --- /dev/null
| | +++ b/reach.t
| | @@ -0,0 +1 @@
| | +reach
| |
|  \
*-. \   commit COMMIT_OBJECT_NAME
|\ \ \  Merge: MERGE_PARENTS
| | | | Author: A U Thor <author@example.com>
| | | |
| | | |     Merge HEADS DESCRIPTION
| | | |
| | * | commit COMMIT_OBJECT_NAME
| | |/  Author: A U Thor <author@example.com>
| | |
| | |       octopus-b
| | |   ---
| | |    octopus-b.t | 1 +
| | |    1 file changed, 1 insertion(+)
| | |
| | |   diff --git a/octopus-b.t b/octopus-b.t
| | |   new file mode 100644
| | |   index 0000000..d5fcad0
| | |   --- /dev/null
| | |   +++ b/octopus-b.t
| | |   @@ -0,0 +1 @@
| | |   +octopus-b
| | |
| * | commit COMMIT_OBJECT_NAME
| |/  Author: A U Thor <author@example.com>
| |
| |       octopus-a
| |   ---
| |    octopus-a.t | 1 +
| |    1 file changed, 1 insertion(+)
| |
| |   diff --git a/octopus-a.t b/octopus-a.t
| |   new file mode 100644
| |   index 0000000..11ee015
| |   --- /dev/null
| |   +++ b/octopus-a.t
| |   @@ -0,0 +1 @@
| |   +octopus-a
| |
* | commit COMMIT_OBJECT_NAME
|/  Author: A U Thor <author@example.com>
|
|       seventh
|   ---
|    seventh.t | 1 +
|    1 file changed, 1 insertion(+)
|
|   diff --git a/seventh.t b/seventh.t
|   new file mode 100644
|   index 0000000..9744ffc
|   --- /dev/null
|   +++ b/seventh.t
|   @@ -0,0 +1 @@
|   +seventh
|
*   commit COMMIT_OBJECT_NAME
|\  Merge: MERGE_PARENTS
| | Author: A U Thor <author@example.com>
| |
| |     Merge branch 'tangle'
| |
| *   commit COMMIT_OBJECT_NAME
| |\  Merge: MERGE_PARENTS
| | | Author: A U Thor <author@example.com>
| | |
| | |     Merge branch 'side' (early part) into tangle
| | |
| * |   commit COMMIT_OBJECT_NAME
| |\ \  Merge: MERGE_PARENTS
| | | | Author: A U Thor <author@example.com>
| | | |
| | | |     Merge branch 'master' (early part) into tangle
| | | |
| * | | commit COMMIT_OBJECT_NAME
| | | | Author: A U Thor <author@example.com>
| | | |
| | | |     tangle-a
| | | | ---
| | | |  tangle-a | 1 +
| | | |  1 file changed, 1 insertion(+)
| | | |
| | | | diff --git a/tangle-a b/tangle-a
| | | | new file mode 100644
| | | | index 0000000..7898192
| | | | --- /dev/null
| | | | +++ b/tangle-a
| | | | @@ -0,0 +1 @@
| | | | +a
| | | |
* | | |   commit COMMIT_OBJECT_NAME
|\ \ \ \  Merge: MERGE_PARENTS
| | | | | Author: A U Thor <author@example.com>
| | | | |
| | | | |     Merge branch 'side'
| | | | |
| * | | | commit COMMIT_OBJECT_NAME
| | |_|/  Author: A U Thor <author@example.com>
| |/| |
| | | |       side-2
| | | |   ---
| | | |    2 | 1 +
| | | |    1 file changed, 1 insertion(+)
| | | |
| | | |   diff --git a/2 b/2
| | | |   new file mode 100644
| | | |   index 0000000..0cfbf08
| | | |   --- /dev/null
| | | |   +++ b/2
| | | |   @@ -0,0 +1 @@
| | | |   +2
| | | |
| * | | commit COMMIT_OBJECT_NAME
| | | | Author: A U Thor <author@example.com>
| | | |
| | | |     side-1
| | | | ---
| | | |  1 | 1 +
| | | |  1 file changed, 1 insertion(+)
| | | |
| | | | diff --git a/1 b/1
| | | | new file mode 100644
| | | | index 0000000..d00491f
| | | | --- /dev/null
| | | | +++ b/1
| | | | @@ -0,0 +1 @@
| | | | +1
| | | |
* | | | commit COMMIT_OBJECT_NAME
| | | | Author: A U Thor <author@example.com>
| | | |
| | | |     Second
| | | | ---
| | | |  one | 1 +
| | | |  1 file changed, 1 insertion(+)
| | | |
| | | | diff --git a/one b/one
| | | | new file mode 100644
| | | | index 0000000..9a33383
| | | | --- /dev/null
| | | | +++ b/one
| | | | @@ -0,0 +1 @@
| | | | +case
| | | |
* | | | commit COMMIT_OBJECT_NAME
| |_|/  Author: A U Thor <author@example.com>
|/| |
| | |       sixth
| | |   ---
| | |    a/two | 1 -
| | |    1 file changed, 1 deletion(-)
| | |
| | |   diff --git a/a/two b/a/two
| | |   deleted file mode 100644
| | |   index 9245af5..0000000
| | |   --- a/a/two
| | |   +++ /dev/null
| | |   @@ -1 +0,0 @@
| | |   -ni
| | |
* | | commit COMMIT_OBJECT_NAME
| | | Author: A U Thor <author@example.com>
| | |
| | |     fifth
| | | ---
| | |  a/two | 1 +
| | |  1 file changed, 1 insertion(+)
| | |
| | | diff --git a/a/two b/a/two
| | | new file mode 100644
| | | index 0000000..9245af5
| | | --- /dev/null
| | | +++ b/a/two
| | | @@ -0,0 +1 @@
| | | +ni
| | |
* | | commit COMMIT_OBJECT_NAME
|/ /  Author: A U Thor <author@example.com>
| |
| |       fourth
| |   ---
| |    ein | 1 +
| |    1 file changed, 1 insertion(+)
| |
| |   diff --git a/ein b/ein
| |   new file mode 100644
| |   index 0000000..9d7e69f
| |   --- /dev/null
| |   +++ b/ein
| |   @@ -0,0 +1 @@
| |   +ichi
| |
* | commit COMMIT_OBJECT_NAME
|/  Author: A U Thor <author@example.com>
|
|       third
|   ---
|    ichi | 1 +
|    one  | 1 -
|    2 files changed, 1 insertion(+), 1 deletion(-)
|
|   diff --git a/ichi b/ichi
|   new file mode 100644
|   index 0000000..9d7e69f
|   --- /dev/null
|   +++ b/ichi
|   @@ -0,0 +1 @@
|   +ichi
|   diff --git a/one b/one
|   deleted file mode 100644
|   index 9d7e69f..0000000
|   --- a/one
|   +++ /dev/null
|   @@ -1 +0,0 @@
|   -ichi
|
* commit COMMIT_OBJECT_NAME
| Author: A U Thor <author@example.com>
|
|     second
| ---
|  one | 2 +-
|  1 file changed, 1 insertion(+), 1 deletion(-)
|
| diff --git a/one b/one
| index 5626abf..9d7e69f 100644
| --- a/one
| +++ b/one
| @@ -1 +1 @@
| -one
| +ichi
|
* commit COMMIT_OBJECT_NAME
  Author: A U Thor <author@example.com>

      initial
  ---
   one | 1 +
   1 file changed, 1 insertion(+)

  diff --git a/one b/one
  new file mode 100644
  index 0000000..5626abf
  --- /dev/null
  +++ b/one
  @@ -0,0 +1 @@
  +one
EOF

sanitize_output () {
	sed -e 's/ *$//' \
	    -e 's/commit [0-9a-f]*$/commit COMMIT_OBJECT_NAME/' \
	    -e 's/Merge: [ 0-9a-f]*$/Merge: MERGE_PARENTS/' \
	    -e 's/Merge tag.*/Merge HEADS DESCRIPTION/' \
	    -e 's/Merge commit.*/Merge HEADS DESCRIPTION/' \
	    -e 's/, 0 deletions(-)//' \
	    -e 's/, 0 insertions(+)//' \
	    -e 's/ 1 files changed, / 1 file changed, /' \
	    -e 's/, 1 deletions(-)/, 1 deletion(-)/' \
	    -e 's/, 1 insertions(+)/, 1 insertion(+)/'
}

test_expect_success 'log --graph with diff and stats' '
	git log --no-renames --graph --pretty=short --stat -p >actual &&
	sanitize_output >actual.sanitized <actual &&
	test_i18ncmp expect actual.sanitized
'

cat >expect <<\EOF
*** *   commit COMMIT_OBJECT_NAME
*** |\  Merge: MERGE_PARENTS
*** | | Author: A U Thor <author@example.com>
*** | |
*** | |     Merge HEADS DESCRIPTION
*** | |
*** | * commit COMMIT_OBJECT_NAME
*** | | Author: A U Thor <author@example.com>
*** | |
*** | |     reach
*** | | ---
*** | |  reach.t | 1 +
*** | |  1 file changed, 1 insertion(+)
*** | |
*** | | diff --git a/reach.t b/reach.t
*** | | new file mode 100644
*** | | index 0000000..10c9591
*** | | --- /dev/null
*** | | +++ b/reach.t
*** | | @@ -0,0 +1 @@
*** | | +reach
*** | |
*** |  \
*** *-. \   commit COMMIT_OBJECT_NAME
*** |\ \ \  Merge: MERGE_PARENTS
*** | | | | Author: A U Thor <author@example.com>
*** | | | |
*** | | | |     Merge HEADS DESCRIPTION
*** | | | |
*** | | * | commit COMMIT_OBJECT_NAME
*** | | |/  Author: A U Thor <author@example.com>
*** | | |
*** | | |       octopus-b
*** | | |   ---
*** | | |    octopus-b.t | 1 +
*** | | |    1 file changed, 1 insertion(+)
*** | | |
*** | | |   diff --git a/octopus-b.t b/octopus-b.t
*** | | |   new file mode 100644
*** | | |   index 0000000..d5fcad0
*** | | |   --- /dev/null
*** | | |   +++ b/octopus-b.t
*** | | |   @@ -0,0 +1 @@
*** | | |   +octopus-b
*** | | |
*** | * | commit COMMIT_OBJECT_NAME
*** | |/  Author: A U Thor <author@example.com>
*** | |
*** | |       octopus-a
*** | |   ---
*** | |    octopus-a.t | 1 +
*** | |    1 file changed, 1 insertion(+)
*** | |
*** | |   diff --git a/octopus-a.t b/octopus-a.t
*** | |   new file mode 100644
*** | |   index 0000000..11ee015
*** | |   --- /dev/null
*** | |   +++ b/octopus-a.t
*** | |   @@ -0,0 +1 @@
*** | |   +octopus-a
*** | |
*** * | commit COMMIT_OBJECT_NAME
*** |/  Author: A U Thor <author@example.com>
*** |
*** |       seventh
*** |   ---
*** |    seventh.t | 1 +
*** |    1 file changed, 1 insertion(+)
*** |
*** |   diff --git a/seventh.t b/seventh.t
*** |   new file mode 100644
*** |   index 0000000..9744ffc
*** |   --- /dev/null
*** |   +++ b/seventh.t
*** |   @@ -0,0 +1 @@
*** |   +seventh
*** |
*** *   commit COMMIT_OBJECT_NAME
*** |\  Merge: MERGE_PARENTS
*** | | Author: A U Thor <author@example.com>
*** | |
*** | |     Merge branch 'tangle'
*** | |
*** | *   commit COMMIT_OBJECT_NAME
*** | |\  Merge: MERGE_PARENTS
*** | | | Author: A U Thor <author@example.com>
*** | | |
*** | | |     Merge branch 'side' (early part) into tangle
*** | | |
*** | * |   commit COMMIT_OBJECT_NAME
*** | |\ \  Merge: MERGE_PARENTS
*** | | | | Author: A U Thor <author@example.com>
*** | | | |
*** | | | |     Merge branch 'master' (early part) into tangle
*** | | | |
*** | * | | commit COMMIT_OBJECT_NAME
*** | | | | Author: A U Thor <author@example.com>
*** | | | |
*** | | | |     tangle-a
*** | | | | ---
*** | | | |  tangle-a | 1 +
*** | | | |  1 file changed, 1 insertion(+)
*** | | | |
*** | | | | diff --git a/tangle-a b/tangle-a
*** | | | | new file mode 100644
*** | | | | index 0000000..7898192
*** | | | | --- /dev/null
*** | | | | +++ b/tangle-a
*** | | | | @@ -0,0 +1 @@
*** | | | | +a
*** | | | |
*** * | | |   commit COMMIT_OBJECT_NAME
*** |\ \ \ \  Merge: MERGE_PARENTS
*** | | | | | Author: A U Thor <author@example.com>
*** | | | | |
*** | | | | |     Merge branch 'side'
*** | | | | |
*** | * | | | commit COMMIT_OBJECT_NAME
*** | | |_|/  Author: A U Thor <author@example.com>
*** | |/| |
*** | | | |       side-2
*** | | | |   ---
*** | | | |    2 | 1 +
*** | | | |    1 file changed, 1 insertion(+)
*** | | | |
*** | | | |   diff --git a/2 b/2
*** | | | |   new file mode 100644
*** | | | |   index 0000000..0cfbf08
*** | | | |   --- /dev/null
*** | | | |   +++ b/2
*** | | | |   @@ -0,0 +1 @@
*** | | | |   +2
*** | | | |
*** | * | | commit COMMIT_OBJECT_NAME
*** | | | | Author: A U Thor <author@example.com>
*** | | | |
*** | | | |     side-1
*** | | | | ---
*** | | | |  1 | 1 +
*** | | | |  1 file changed, 1 insertion(+)
*** | | | |
*** | | | | diff --git a/1 b/1
*** | | | | new file mode 100644
*** | | | | index 0000000..d00491f
*** | | | | --- /dev/null
*** | | | | +++ b/1
*** | | | | @@ -0,0 +1 @@
*** | | | | +1
*** | | | |
*** * | | | commit COMMIT_OBJECT_NAME
*** | | | | Author: A U Thor <author@example.com>
*** | | | |
*** | | | |     Second
*** | | | | ---
*** | | | |  one | 1 +
*** | | | |  1 file changed, 1 insertion(+)
*** | | | |
*** | | | | diff --git a/one b/one
*** | | | | new file mode 100644
*** | | | | index 0000000..9a33383
*** | | | | --- /dev/null
*** | | | | +++ b/one
*** | | | | @@ -0,0 +1 @@
*** | | | | +case
*** | | | |
*** * | | | commit COMMIT_OBJECT_NAME
*** | |_|/  Author: A U Thor <author@example.com>
*** |/| |
*** | | |       sixth
*** | | |   ---
*** | | |    a/two | 1 -
*** | | |    1 file changed, 1 deletion(-)
*** | | |
*** | | |   diff --git a/a/two b/a/two
*** | | |   deleted file mode 100644
*** | | |   index 9245af5..0000000
*** | | |   --- a/a/two
*** | | |   +++ /dev/null
*** | | |   @@ -1 +0,0 @@
*** | | |   -ni
*** | | |
*** * | | commit COMMIT_OBJECT_NAME
*** | | | Author: A U Thor <author@example.com>
*** | | |
*** | | |     fifth
*** | | | ---
*** | | |  a/two | 1 +
*** | | |  1 file changed, 1 insertion(+)
*** | | |
*** | | | diff --git a/a/two b/a/two
*** | | | new file mode 100644
*** | | | index 0000000..9245af5
*** | | | --- /dev/null
*** | | | +++ b/a/two
*** | | | @@ -0,0 +1 @@
*** | | | +ni
*** | | |
*** * | | commit COMMIT_OBJECT_NAME
*** |/ /  Author: A U Thor <author@example.com>
*** | |
*** | |       fourth
*** | |   ---
*** | |    ein | 1 +
*** | |    1 file changed, 1 insertion(+)
*** | |
*** | |   diff --git a/ein b/ein
*** | |   new file mode 100644
*** | |   index 0000000..9d7e69f
*** | |   --- /dev/null
*** | |   +++ b/ein
*** | |   @@ -0,0 +1 @@
*** | |   +ichi
*** | |
*** * | commit COMMIT_OBJECT_NAME
*** |/  Author: A U Thor <author@example.com>
*** |
*** |       third
*** |   ---
*** |    ichi | 1 +
*** |    one  | 1 -
*** |    2 files changed, 1 insertion(+), 1 deletion(-)
*** |
*** |   diff --git a/ichi b/ichi
*** |   new file mode 100644
*** |   index 0000000..9d7e69f
*** |   --- /dev/null
*** |   +++ b/ichi
*** |   @@ -0,0 +1 @@
*** |   +ichi
*** |   diff --git a/one b/one
*** |   deleted file mode 100644
*** |   index 9d7e69f..0000000
*** |   --- a/one
*** |   +++ /dev/null
*** |   @@ -1 +0,0 @@
*** |   -ichi
*** |
*** * commit COMMIT_OBJECT_NAME
*** | Author: A U Thor <author@example.com>
*** |
*** |     second
*** | ---
*** |  one | 2 +-
*** |  1 file changed, 1 insertion(+), 1 deletion(-)
*** |
*** | diff --git a/one b/one
*** | index 5626abf..9d7e69f 100644
*** | --- a/one
*** | +++ b/one
*** | @@ -1 +1 @@
*** | -one
*** | +ichi
*** |
*** * commit COMMIT_OBJECT_NAME
***   Author: A U Thor <author@example.com>
***
***       initial
***   ---
***    one | 1 +
***    1 file changed, 1 insertion(+)
***
***   diff --git a/one b/one
***   new file mode 100644
***   index 0000000..5626abf
***   --- /dev/null
***   +++ b/one
***   @@ -0,0 +1 @@
***   +one
EOF

test_expect_success 'log --line-prefix="*** " --graph with diff and stats' '
	git log --line-prefix="*** " --no-renames --graph --pretty=short --stat -p >actual &&
	sanitize_output >actual.sanitized <actual &&
	test_i18ncmp expect actual.sanitized
'

cat >expect <<-\EOF
* reach
|
| A	reach.t
* Merge branch 'tangle'
*   Merge branch 'side'
|\
| * side-2
|
|   A	2
* Second
|
| A	one
* sixth

  D	a/two
EOF

test_expect_success 'log --graph with --name-status' '
	git log --graph --format=%s --name-status tangle..reach >actual &&
	sanitize_output <actual >actual.sanitized &&
	test_cmp expect actual.sanitized
'

cat >expect <<-\EOF
* reach
|
| reach.t
* Merge branch 'tangle'
*   Merge branch 'side'
|\
| * side-2
|
|   2
* Second
|
| one
* sixth

  a/two
EOF

test_expect_success 'log --graph with --name-only' '
	git log --graph --format=%s --name-only tangle..reach >actual &&
	sanitize_output <actual >actual.sanitized &&
	test_cmp expect actual.sanitized
'

test_expect_success 'dotdot is a parent directory' '
	mkdir -p a/b &&
	( echo sixth && echo fifth ) >expect &&
	( cd a/b && git log --format=%s .. ) >actual &&
	test_cmp expect actual
'

test_expect_success GPG 'setup signed branch' '
	test_when_finished "git reset --hard && git checkout master" &&
	git checkout -b signed master &&
	echo foo >foo &&
	git add foo &&
	git commit -S -m signed_commit
'

test_expect_success GPG 'log --graph --show-signature' '
	git log --graph --show-signature -n1 signed >actual &&
	grep "^| gpg: Signature made" actual &&
	grep "^| gpg: Good signature" actual
'

test_expect_success GPG 'log --graph --show-signature for merged tag' '
	test_when_finished "git reset --hard && git checkout master" &&
	git checkout -b plain master &&
	echo aaa >bar &&
	git add bar &&
	git commit -m bar_commit &&
	git checkout -b tagged master &&
	echo bbb >baz &&
	git add baz &&
	git commit -m baz_commit &&
	git tag -s -m signed_tag_msg signed_tag &&
	git checkout plain &&
	git merge --no-ff -m msg signed_tag &&
	git log --graph --show-signature -n1 plain >actual &&
	grep "^|\\\  merged tag" actual &&
	grep "^| | gpg: Signature made" actual &&
	grep "^| | gpg: Good signature" actual
'

test_expect_success GPG '--no-show-signature overrides --show-signature' '
	git log -1 --show-signature --no-show-signature signed >actual &&
	! grep "^gpg:" actual
'

test_expect_success GPG 'log.showsignature=true behaves like --show-signature' '
	test_config log.showsignature true &&
	git log -1 signed >actual &&
	grep "gpg: Signature made" actual &&
	grep "gpg: Good signature" actual
'

test_expect_success GPG '--no-show-signature overrides log.showsignature=true' '
	test_config log.showsignature true &&
	git log -1 --no-show-signature signed >actual &&
	! grep "^gpg:" actual
'

test_expect_success GPG '--show-signature overrides log.showsignature=false' '
	test_config log.showsignature false &&
	git log -1 --show-signature signed >actual &&
	grep "gpg: Signature made" actual &&
	grep "gpg: Good signature" actual
'

test_expect_success 'log --graph --no-walk is forbidden' '
	test_must_fail git log --graph --no-walk
'

test_expect_success 'log diagnoses bogus HEAD' '
	git init empty &&
	test_must_fail git -C empty log 2>stderr &&
	test_i18ngrep does.not.have.any.commits stderr &&
	echo 1234abcd >empty/.git/refs/heads/master &&
	test_must_fail git -C empty log 2>stderr &&
	test_i18ngrep broken stderr &&
	echo "ref: refs/heads/invalid.lock" >empty/.git/HEAD &&
	test_must_fail git -C empty log 2>stderr &&
	test_i18ngrep broken stderr &&
	test_must_fail git -C empty log --default totally-bogus 2>stderr &&
	test_i18ngrep broken stderr
'

test_expect_success 'log does not default to HEAD when rev input is given' '
	>expect &&
	git log --branches=does-not-exist >actual &&
	test_cmp expect actual
'

test_expect_success 'set up --source tests' '
	git checkout --orphan source-a &&
	test_commit one &&
	test_commit two &&
	git checkout -b source-b HEAD^ &&
	test_commit three
'

test_expect_success 'log --source paints branch names' '
	cat >expect <<-\EOF &&
	09e12a9	source-b three
	8e393e1	source-a two
	1ac6c77	source-b one
	EOF
	git log --oneline --source source-a source-b >actual &&
	test_cmp expect actual
'

test_expect_success 'log --source paints tag names' '
	git tag -m tagged source-tag &&
	cat >expect <<-\EOF &&
	09e12a9	source-tag three
	8e393e1	source-a two
	1ac6c77	source-tag one
	EOF
	git log --oneline --source source-tag source-a >actual &&
	test_cmp expect actual
'

test_expect_success 'log --source paints symmetric ranges' '
	cat >expect <<-\EOF &&
	09e12a9	source-b three
	8e393e1	source-a two
	EOF
	git log --oneline --source source-a...source-b >actual &&
	test_cmp expect actual
'

test_done
