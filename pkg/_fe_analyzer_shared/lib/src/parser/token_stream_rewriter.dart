// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../scanner/error_token.dart' show UnmatchedToken;

import '../scanner/token.dart'
    show
        BeginToken,
        CommentToken,
        Keyword,
        SimpleToken,
        SyntheticBeginToken,
        SyntheticKeywordToken,
        SyntheticStringToken,
        SyntheticToken,
        Token,
        TokenType;

abstract class TokenStreamRewriter with _TokenStreamMixin {
  /// Insert a synthetic open and close parenthesis and return the new synthetic
  /// open parenthesis. If [insertIdentifier] is true, then a synthetic
  /// identifier is included between the open and close parenthesis.
  Token insertParens(Token token, bool includeIdentifier) {
    Token next = token.next;
    int offset = next.charOffset;
    BeginToken leftParen =
        next = new SyntheticBeginToken(TokenType.OPEN_PAREN, offset);
    if (includeIdentifier) {
      next = _setNext(
          next, new SyntheticStringToken(TokenType.IDENTIFIER, '', offset, 0));
    }
    next = _setNext(next, new SyntheticToken(TokenType.CLOSE_PAREN, offset));
    _setEndGroup(leftParen, next);
    _setNext(next, token.next);

    // A no-op rewriter could skip this step.
    _setNext(token, leftParen);

    return leftParen;
  }

  /// Insert [newToken] after [token] and return [newToken].
  Token insertToken(Token token, Token newToken) {
    _setNext(newToken, token.next);

    // A no-op rewriter could skip this step.
    _setNext(token, newToken);

    return newToken;
  }

  /// Move [endGroup] (a synthetic `)`, `]`, or `}` token) and associated
  /// error token after [token] in the token stream and return [endGroup].
  Token moveSynthetic(Token token, Token endGroup) {
    assert(endGroup.beforeSynthetic != null);
    if (token == endGroup) return endGroup;
    Token errorToken;
    if (endGroup.next is UnmatchedToken) {
      errorToken = endGroup.next;
    }

    // Remove endGroup from its current location
    _setNext(endGroup.beforeSynthetic, (errorToken ?? endGroup).next);

    // Insert endGroup into its new location
    Token next = token.next;
    _setNext(token, endGroup);
    _setNext(errorToken ?? endGroup, next);
    _setOffset(endGroup, next.offset);
    if (errorToken != null) {
      _setOffset(errorToken, next.offset);
    }

    return endGroup;
  }

  /// Replace the single token immediately following the [previousToken] with
  /// the chain of tokens starting at the [replacementToken]. Return the
  /// [replacementToken].
  Token replaceTokenFollowing(Token previousToken, Token replacementToken) {
    Token replacedToken = previousToken.next;
    _setNext(previousToken, replacementToken);

    _setPrecedingComments(
        replacementToken as SimpleToken, replacedToken.precedingComments);

    _setNext(_lastTokenInChain(replacementToken), replacedToken.next);

    return replacementToken;
  }

  /// Given the [firstToken] in a chain of tokens to be inserted, return the
  /// last token in the chain.
  ///
  /// As a side-effect, this method also ensures that the tokens in the chain
  /// have their `previous` pointers set correctly.
  Token _lastTokenInChain(Token firstToken) {
    Token previous;
    Token current = firstToken;
    while (current.next != null && current.next.type != TokenType.EOF) {
      if (previous != null) {
        _setPrevious(current, previous);
      }
      previous = current;
      current = current.next;
    }
    if (previous != null) {
      _setPrevious(current, previous);
    }
    return current;
  }

  Token _setNext(Token setOn, Token nextToken);
  void _setEndGroup(BeginToken setOn, Token endGroup);
  void _setOffset(Token setOn, int offset);
  void _setPrecedingComments(SimpleToken setOn, CommentToken comment);
  void _setPrevious(Token setOn, Token previous);
}

/// Provides the capability of inserting tokens into a token stream. This
/// implementation does this by rewriting the previous token to point to the
/// inserted token.
class TokenStreamRewriterImpl extends TokenStreamRewriter {
  // TODO(brianwilkerson):
  //
  // When we get to the point of removing `token.previous`, the plan is to
  // convert this into an interface and provide two implementations.
  //
  // One, used by Fasta, will connect the inserted tokens to the following token
  // without modifying the previous token.
  //
  // The other, used by 'analyzer', will be created with the first token in the
  // stream (actually with the BOF marker at the beginning of the stream). It
  // will be created only when invoking 'analyzer' specific parse methods (in
  // `Parser`), such as
  //
  // Token parseUnitWithRewrite(Token bof) {
  //   rewriter = AnalyzerTokenStreamRewriter(bof);
  //   return parseUnit(bof.next);
  // }
  //

  Token _setNext(Token setOn, Token nextToken) {
    return setOn.setNext(nextToken);
  }

  void _setEndGroup(BeginToken setOn, Token endGroup) {
    setOn.endGroup = endGroup;
  }

  void _setOffset(Token setOn, int offset) {
    setOn.offset = offset;
  }

  void _setPrecedingComments(SimpleToken setOn, CommentToken comment) {
    setOn.precedingComments = comment;
  }

  void _setPrevious(Token setOn, Token previous) {
    setOn.previous = previous;
  }
}

/// Provides the capability of adding tokens that lead into a token stream
/// without modifying the original token stream and not setting the any token's
/// `previous` field.
class TokenStreamGhostWriter
    with _TokenStreamMixin
    implements TokenStreamRewriter {
  @override
  Token insertParens(Token token, bool includeIdentifier) {
    Token next = token.next;
    int offset = next.charOffset;
    BeginToken leftParen =
        next = new SyntheticBeginToken(TokenType.OPEN_PAREN, offset);
    if (includeIdentifier) {
      Token identifier =
          new SyntheticStringToken(TokenType.IDENTIFIER, '', offset, 0);
      next.next = identifier;
      next = identifier;
    }
    Token rightParen = new SyntheticToken(TokenType.CLOSE_PAREN, offset);
    next.next = rightParen;
    rightParen.next = token.next;

    return leftParen;
  }

  @override
  Token insertToken(Token token, Token newToken) {
    newToken.next = token.next;
    return newToken;
  }

  @override
  Token moveSynthetic(Token token, Token endGroup) {
    Token newEndGroup =
        new SyntheticToken(endGroup.type, token.next.charOffset);
    newEndGroup.next = token.next;
    return newEndGroup;
  }

  @override
  Token replaceTokenFollowing(Token previousToken, Token replacementToken) {
    Token replacedToken = previousToken.next;

    (replacementToken as SimpleToken).precedingComments =
        replacedToken.precedingComments;

    _lastTokenInChain(replacementToken).next = replacedToken.next;
    return replacementToken;
  }

  /// Given the [firstToken] in a chain of tokens to be inserted, return the
  /// last token in the chain.
  Token _lastTokenInChain(Token firstToken) {
    Token current = firstToken;
    while (current.next != null && current.next.type != TokenType.EOF) {
      current = current.next;
    }
    return current;
  }

  @override
  void _setEndGroup(BeginToken setOn, Token endGroup) {
    throw UnimplementedError("_setEndGroup");
  }

  @override
  Token _setNext(Token setOn, Token nextToken) {
    throw UnimplementedError("_setNext");
  }

  @override
  void _setOffset(Token setOn, int offset) {
    throw UnimplementedError("_setOffset");
  }

  @override
  void _setPrecedingComments(SimpleToken setOn, CommentToken comment) {
    throw UnimplementedError("_setPrecedingComments");
  }

  @override
  void _setPrevious(Token setOn, Token previous) {
    throw UnimplementedError("_setPrevious");
  }
}

mixin _TokenStreamMixin {
  /// Insert a synthetic identifier after [token] and return the new identifier.
  Token insertSyntheticIdentifier(Token token, [String value]) {
    return insertToken(
        token,
        new SyntheticStringToken(
            TokenType.IDENTIFIER, value ?? '', token.next.charOffset, 0));
  }

  /// Insert a new synthetic [keyword] after [token] and return the new token.
  Token insertSyntheticKeyword(Token token, Keyword keyword) => insertToken(
      token, new SyntheticKeywordToken(keyword, token.next.charOffset));

  /// Insert a new simple synthetic token of [newTokenType] after [token]
  /// and return the new token.
  Token insertSyntheticToken(Token token, TokenType newTokenType) {
    assert(newTokenType is! Keyword, 'use insertSyntheticKeyword instead');
    return insertToken(
        token, new SyntheticToken(newTokenType, token.next.charOffset));
  }

  /// Insert [newToken] after [token] and return [newToken].
  Token insertToken(Token token, Token newToken);
}

abstract class TokenStreamChange {
  void undo();
}

class NextTokenStreamChange implements TokenStreamChange {
  Token setOn;
  Token setOnNext;
  Token nextToken;
  Token nextTokenPrevious;
  Token nextTokenBeforeSynthetic;

  NextTokenStreamChange(UndoableTokenStreamRewriter rewriter) {
    rewriter._changes.add(this);
  }

  Token setNext(Token setOn, Token nextToken) {
    this.setOn = setOn;
    this.setOnNext = setOn.next;
    this.nextToken = nextToken;
    this.nextTokenPrevious = nextToken.previous;
    this.nextTokenBeforeSynthetic = nextToken.beforeSynthetic;

    setOn.next = nextToken;
    nextToken.previous = setOn;
    nextToken.beforeSynthetic = setOn;

    return nextToken;
  }

  @override
  void undo() {
    nextToken.beforeSynthetic = nextTokenBeforeSynthetic;
    nextToken.previous = nextTokenPrevious;
    setOn.next = setOnNext;
  }
}

class EndGroupTokenStreamChange implements TokenStreamChange {
  BeginToken setOn;
  Token endGroup;

  EndGroupTokenStreamChange(UndoableTokenStreamRewriter rewriter) {
    rewriter._changes.add(this);
  }

  void setEndGroup(BeginToken setOn, Token endGroup) {
    this.setOn = setOn;
    this.endGroup = setOn.endGroup;

    setOn.endGroup = endGroup;
  }

  @override
  void undo() {
    setOn.endGroup = endGroup;
  }
}

class OffsetTokenStreamChange implements TokenStreamChange {
  Token setOn;
  int offset;

  OffsetTokenStreamChange(UndoableTokenStreamRewriter rewriter) {
    rewriter._changes.add(this);
  }

  void setOffset(Token setOn, int offset) {
    this.setOn = setOn;
    this.offset = setOn.offset;

    setOn.offset = offset;
  }

  @override
  void undo() {
    setOn.offset = offset;
  }
}

class PrecedingCommentsTokenStreamChange implements TokenStreamChange {
  SimpleToken setOn;
  CommentToken comment;

  PrecedingCommentsTokenStreamChange(UndoableTokenStreamRewriter rewriter) {
    rewriter._changes.add(this);
  }

  void setPrecedingComments(SimpleToken setOn, CommentToken comment) {
    this.setOn = setOn;
    this.comment = setOn.precedingComments;

    setOn.precedingComments = comment;
  }

  @override
  void undo() {
    setOn.precedingComments = comment;
  }
}

class PreviousTokenStreamChange implements TokenStreamChange {
  Token setOn;
  Token previous;

  PreviousTokenStreamChange(UndoableTokenStreamRewriter rewriter) {
    rewriter._changes.add(this);
  }

  void setPrevious(Token setOn, Token previous) {
    this.setOn = setOn;
    this.previous = setOn.previous;

    setOn.previous = previous;
  }

  @override
  void undo() {
    setOn.previous = previous;
  }
}

/// Provides the capability of inserting tokens into a token stream. This
/// implementation does this by rewriting the previous token to point to the
/// inserted token. It also allows to undo these changes.
class UndoableTokenStreamRewriter extends TokenStreamRewriter {
  List<TokenStreamChange> _changes = new List<TokenStreamChange>();

  void undo() {
    for (int i = _changes.length - 1; i >= 0; i--) {
      TokenStreamChange change = _changes[i];
      change.undo();
    }
    _changes.clear();
  }

  @override
  void _setEndGroup(BeginToken setOn, Token endGroup) {
    new EndGroupTokenStreamChange(this).setEndGroup(setOn, endGroup);
  }

  @override
  Token _setNext(Token setOn, Token nextToken) {
    return new NextTokenStreamChange(this).setNext(setOn, nextToken);
  }

  @override
  void _setOffset(Token setOn, int offset) {
    new OffsetTokenStreamChange(this).setOffset(setOn, offset);
  }

  @override
  void _setPrecedingComments(SimpleToken setOn, CommentToken comment) {
    new PrecedingCommentsTokenStreamChange(this)
        .setPrecedingComments(setOn, comment);
  }

  @override
  void _setPrevious(Token setOn, Token previous) {
    new PreviousTokenStreamChange(this).setPrevious(setOn, previous);
  }
}
