FROM jekyll/jekyll:latest as build

WORKDIR /srv/jekyll

ADD . /srv/jekyll

COPY ./* /srv/jekyll/

RUN gem install bundler:2.5.23 && \
    rm -rf Gemfile.lock && \
    chmod -R 777 ${PWD} && \
    bundle update && \
    bundle install
    # jekyll build && \
    # jekyll serve --livereload --drafts --trace

ARG build_command
ENV BUILD_COMMAND ${build_command}

CMD sh -c "bundle install && tail -f /dev/null"

# EXPOSE 4000
