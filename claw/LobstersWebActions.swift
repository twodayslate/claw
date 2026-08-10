//
//  LobstersWebActions.swift
//  claw
//

enum LobstersWebActions {
    static let storyVote = """
    const story = document.getElementById('story_' + shortID);
    if (!story) return { upvoted: null, stage: 'locate-story', error: 'Story not found' };
    const currentState = story.classList.contains('upvoted');
    if (currentState === desiredState) {
      return { upvoted: currentState, stage: 'already-matched' };
    }
    const voter = story.querySelector('a.upvoter');
    if (!voter) {
      return { upvoted: currentState, stage: 'locate-control', error: 'Vote control not found' };
    }
    try {
      const requestDetails = await performClawClick(
        voter,
        '/stories/' + shortID + '/',
        () => ({
          stage: 'request-completed',
          pagePath: location.pathname,
          documentState: document.readyState,
          online: navigator.onLine
        })
      );
      await waitForVoteState(story, desiredState);
      return {
        ...requestDetails,
        upvoted: story.classList.contains('upvoted')
      };
    } catch (error) {
      return {
        upvoted: story.classList.contains('upvoted'),
        stage: 'click-or-request',
        error: error instanceof Error ? error.message : String(error),
        pagePath: location.pathname,
        documentState: document.readyState,
        online: navigator.onLine,
        requestPath: error?.requestPath ?? null,
        requestMethod: error?.requestMethod ?? null,
        responseStatus: error?.responseStatus ?? null
      };
    }

    async function waitForVoteState(element, desiredState) {
      const deadline = Date.now() + 1000;
      while (element.classList.contains('upvoted') !== desiredState
             && Date.now() < deadline) {
        await new Promise(resolve => setTimeout(resolve, 25));
      }
    }

    async function performClawClick(control, path, result) {
      const originalFetch = window.fetch;
      let observedRequest = null;
      let resolveAction, rejectAction;
      const preventFallbackNavigation = event => event.preventDefault();
      const completed = new Promise((resolve, reject) => {
        resolveAction = resolve; rejectAction = reject;
      });
      window.fetch = function(input, init) {
        const requestURL = requestURLString(input);
        const responsePromise = Reflect.apply(originalFetch, this, [input, init]);
        if (requestURLMatches(requestURL, path)) {
          const parsedURL = new URL(requestURL, document.baseURI);
          observedRequest = {
            requestPath: parsedURL.pathname,
            requestMethod: String(init?.method || input?.method || 'GET').toUpperCase(),
            responseStatus: null
          };
          responsePromise.then(response => {
            observedRequest.responseStatus = response.status;
            if (response.ok) {
              resolveAction(observedRequest);
            } else {
              rejectAction(withRequestDetails(
                new Error('Lobsters returned HTTP ' + response.status)
              ));
            }
          }, error => rejectAction(withRequestDetails(error)));
        }
        return responsePromise;
      };
      // The vote link can be present before Lobsters installs its delegated
      // click handler. Keep its empty href from reloading the page, and retry
      // the real control until that handler starts the vote request.
      control.addEventListener('click', preventFallbackNavigation, { capture: true });
      try {
        const deadline = Date.now() + 10000;
        while (!observedRequest && Date.now() < deadline) {
          control.click();
          if (!observedRequest) {
            await new Promise(resolve => setTimeout(resolve, 50));
          }
        }
        if (!observedRequest) {
          throw new Error('Lobsters vote handler did not start');
        }
        const requestDetails = await Promise.race([
          completed,
          new Promise((_, reject) => setTimeout(
            () => reject(new Error('Action timed out')),
            Math.max(1, deadline - Date.now())
          ))
        ]);
        return { ...result(), ...requestDetails };
      } catch (error) {
        throw withRequestDetails(error);
      } finally {
        control.removeEventListener('click', preventFallbackNavigation, { capture: true });
        window.fetch = originalFetch;
      }

      function withRequestDetails(error) {
        const failure = error instanceof Error ? error : new Error(String(error));
        if (observedRequest) Object.assign(failure, observedRequest);
        return failure;
      }

      function requestURLString(input) {
        if (typeof input === 'string') return input;
        if (input instanceof URL) return input.href;
        if (input && typeof input.url === 'string') return input.url;
        return String(input || '');
      }

      function requestURLMatches(requestURL, path) {
        try {
          return new URL(requestURL, document.baseURI).pathname.startsWith(path);
        } catch {
          return false;
        }
      }
    }
    """

    static let commentVote = """
    const comment = document.getElementById('c_' + shortID);
    if (!comment) throw new Error('Comment not found');
    const currentState = comment.classList.contains('upvoted');
    if (currentState === desiredState) return { upvoted: currentState };
    const voter = comment.querySelector('button.upvoter');
    if (!voter) throw new Error('Vote control not found');

    const originalFetch = window.fetch;
    let resolveAction, rejectAction;
    const completed = new Promise((resolve, reject) => {
      resolveAction = resolve; rejectAction = reject;
    });
    window.fetch = function(input, init) {
      const requestURL = requestURLString(input);
      const responsePromise = Reflect.apply(originalFetch, this, [input, init]);
      if (requestURLMatches(requestURL, '/comments/' + shortID + '/')) {
        responsePromise.then(response => response.ok
          ? resolveAction()
          : rejectAction(new Error('Lobsters returned HTTP ' + response.status)), rejectAction);
      }
      return responsePromise;
    };
    try {
      voter.click();
      await Promise.race([
        completed,
        new Promise((_, reject) => setTimeout(() => reject(new Error('Vote timed out')), 10000))
      ]);
      const deadline = Date.now() + 1000;
      while (comment.classList.contains('upvoted') !== desiredState
             && Date.now() < deadline) {
        await new Promise(resolve => setTimeout(resolve, 25));
      }
      return { upvoted: comment.classList.contains('upvoted') };
    } finally {
      window.fetch = originalFetch;
    }

    function requestURLString(input) {
      if (typeof input === 'string') return input;
      if (input instanceof URL) return input.href;
      if (input && typeof input.url === 'string') return input.url;
      return String(input || '');
    }

    function requestURLMatches(requestURL, path) {
      try {
        return new URL(requestURL, document.baseURI).pathname.startsWith(path);
      } catch {
        return false;
      }
    }
    """

    static let commentDraft = """
    const comment = document.getElementById('c_' + shortID);
    if (!comment) throw new Error('Comment not found');
    let textarea = comment.querySelector('.comment_form_container textarea[name="comment"]');
    if (!textarea) {
      const editor = comment.querySelector('a.comment_editor');
      if (!editor) throw new Error('Edit control not found');
      editor.click();
      const deadline = Date.now() + 10000;
      while (!textarea && Date.now() < deadline) {
        await new Promise(resolve => setTimeout(resolve, 50));
        textarea = comment.querySelector('.comment_form_container textarea[name="comment"]');
      }
    }
    if (!textarea) throw new Error('Edit form did not load');
    return textarea.value;
    """

    static let submitComment = """
    const waitFor = async finder => {
      const deadline = Date.now() + 10000;
      let value = finder();
      while (!value && Date.now() < deadline) {
        await new Promise(resolve => setTimeout(resolve, 50));
        value = finder();
      }
      return value;
    };

    let form;
    if (mode === 'reply') {
      const parent = document.getElementById('c_' + targetID);
      const replier = parent?.querySelector('a.comment_replier');
      if (!replier) throw new Error('Reply control not found');
      replier.click();
      form = await waitFor(() => document.getElementById('reply_form_c_' + targetID)?.querySelector('.comment_form_container form'));
    } else if (mode === 'edit') {
      const comment = document.getElementById('c_' + targetID);
      let textarea = comment?.querySelector('.comment_form_container textarea[name="comment"]');
      if (!textarea) {
        const editor = comment?.querySelector('a.comment_editor');
        if (!editor) throw new Error('Edit control not found');
        editor.click();
      }
      form = await waitFor(() => comment?.querySelector('.comment_form_container form'));
    } else {
      form = Array.from(document.querySelectorAll('.comment_form_container form')).find(candidate => {
        const story = candidate.querySelector('input[name="story_id"]');
        const parent = candidate.querySelector('input[name="parent_comment_short_id"]');
        return story?.value === storyID && !parent;
      });
    }
    if (!form) throw new Error('Comment form not found');

    const textarea = form.querySelector('textarea[name="comment"]');
    if (!textarea) throw new Error('Comment field not found');
    textarea.value = text;
    textarea.dispatchEvent(new Event('input', { bubbles: true }));

    const originalFetch = window.fetch.bind(window);
    let resolveAction, rejectAction;
    const completed = new Promise((resolve, reject) => {
      resolveAction = resolve; rejectAction = reject;
    });
    window.fetch = function(input, init) {
      const requestURL = typeof input === 'string' ? input : input.url;
      const responsePromise = originalFetch(input, init);
      if (requestURL.includes('/comments')) {
        responsePromise.then(async response => {
          if (!response.ok) {
            rejectAction(new Error('Lobsters returned HTTP ' + response.status));
            return;
          }
          const markup = await response.clone().text();
          const parsed = new DOMParser().parseFromString(markup, 'text/html');
          const error = parsed.querySelector('.error, .flash-error, .flash-warning');
          if (error) {
            rejectAction(new Error(error.textContent.trim()));
            return;
          }

          const persistedComment = parsed.querySelector('.comment[data-shortid]');
          const persistedID = persistedComment?.dataset.shortid || '';
          const matchesTarget = mode !== 'edit' || persistedID === targetID;
          if (!persistedID || !matchesTarget) {
            rejectAction(new Error('Lobsters did not save the comment.'));
            return;
          }
          resolveAction();
        }, rejectAction);
      }
      return responsePromise;
    };
    try {
      form.requestSubmit();
      await Promise.race([
        completed,
        new Promise((_, reject) => setTimeout(() => reject(new Error('Comment timed out')), 10000))
      ]);
      return true;
    } finally {
      window.fetch = originalFetch;
    }
    """

    static let deleteComment = """
    const comment = document.getElementById('c_' + shortID);
    const control = comment?.querySelector('a.comment_deletor');
    if (!control) throw new Error('Delete control not found');
    const originalConfirm = window.confirm;
    const originalFetch = window.fetch.bind(window);
    let resolveAction, rejectAction;
    const completed = new Promise((resolve, reject) => {
      resolveAction = resolve; rejectAction = reject;
    });
    window.confirm = () => true;
    window.fetch = function(input, init) {
      const requestURL = typeof input === 'string' ? input : input.url;
      const responsePromise = originalFetch(input, init);
      if (requestURL.includes('/comments/' + shortID + '/delete')) {
        responsePromise.then(response => response.ok
          ? resolveAction()
          : rejectAction(new Error('Lobsters returned HTTP ' + response.status)), rejectAction);
      }
      return responsePromise;
    };
    try {
      control.click();
      await Promise.race([
        completed,
        new Promise((_, reject) => setTimeout(() => reject(new Error('Delete timed out')), 10000))
      ]);
      return true;
    } finally {
      window.confirm = originalConfirm;
      window.fetch = originalFetch;
    }
    """

    static let logout = """
    if (!document.body?.dataset?.username) return true;
    const form = Array.from(document.querySelectorAll('form')).find(candidate => {
      try {
        const action = new URL(candidate.action, document.baseURI);
        return action.origin === window.location.origin && action.pathname === '/logout';
      } catch { return false; }
    });
    if (!form) return false;
    HTMLFormElement.prototype.submit.call(form);
    return true;
    """
}
