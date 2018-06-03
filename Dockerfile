#####################
#  Building Stage   #
#####################
FROM gitlab/gitlab-ce:10.6.5-ce.0 as builderone
ENV GITLAB_DIR=/opt/gitlab/embedded/service/gitlab-rails
ENV GITLAB_GIT_ZH=https://gitlab.com/xhang/gitlab.git

# Reference:
# * https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/config/software/gitlab-rails.rb
# * https://gitlab.com/gitlab-org/gitlab-ce/blob/master/.gitlab-ci.yml

RUN cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
(echo "deb-src http://archive.ubuntu.com/ubuntu bionic main restricted #Added by software-properties" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted" && \
echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic main restricted multiverse universe #Added by software-properties" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted" && \ 
echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted multiverse universe #Added by software-properties" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic universe" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-updates universe" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic multiverse" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-updates multiverse" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse" && \
echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse #Added by software-properties" && \
echo "deb http://archive.canonical.com/ubuntu bionic partner" && \
echo "deb-src http://archive.canonical.com/ubuntu bionic partner" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted" && \
echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted multiverse universe #Added by software-properties" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-security universe" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-security multiverse") >/etc/apt/sources.list

RUN  apt-get update -q 
RUN  apt-get install -yq build-essential  mysql-client libmysqlclient-dev

RUN set -xe \
    && echo " # Regenerating the assets" \
    && cd ${GITLAB_DIR} \
	&& bundle config mirror.https://rubygems.org https://gems.ruby-china.org \
	&& gem install --verbose mysql2 -v '0.4.10' \
	&& bundle install --with=mysql


#####################
#  Building Stage   #
#####################
FROM gitlab/gitlab-ce:10.7.5-ce.0 as builder

ENV GITLAB_DIR=/opt/gitlab/embedded/service/gitlab-rails
ENV GITLAB_GIT_ZH=https://gitlab.com/xhang/gitlab.git

# Reference:
# * https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/config/software/gitlab-rails.rb
# * https://gitlab.com/gitlab-org/gitlab-ce/blob/master/.gitlab-ci.yml

RUN cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
(echo "deb-src http://archive.ubuntu.com/ubuntu bionic main restricted #Added by software-properties" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted" && \
echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic main restricted multiverse universe #Added by software-properties" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted" && \ 
echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted multiverse universe #Added by software-properties" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic universe" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-updates universe" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic multiverse" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-updates multiverse" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse" && \
echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse #Added by software-properties" && \
echo "deb http://archive.canonical.com/ubuntu bionic partner" && \
echo "deb-src http://archive.canonical.com/ubuntu bionic partner" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted" && \
echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted multiverse universe #Added by software-properties" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-security universe" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-security multiverse") >/etc/apt/sources.list


RUN set -xe \
    && echo " # Preparing ..." \
    && export DEBIAN_FRONTEND=noninteractive \
    && export SSL_CERT_DIR=/etc/ssl/certs/ \
    && export GIT_SSL_CAPATH=/etc/ssl/certs/ \
    && curl -sL https://deb.nodesource.com/setup_6.x | bash - \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -yqq lsb-release patch nodejs python build-essential yarn cmake

RUN set -xe \
    && echo " # Generating translation patch ..." \
    && cd /tmp \
    && git clone ${GITLAB_GIT_ZH} gitlab \
    && cd gitlab \
    && export IGNORE_DIRS=':!spec :!features :!.gitignore :!locale :!app/assets/ :!vendor/assets/' \
    && git diff --diff-filter=d v10.7.5..v10.7.5-zh -- . ${IGNORE_DIRS} > ../zh_CN.diff \
    && echo " # Patching ..." \
    && patch -d ${GITLAB_DIR} -p1 < ../zh_CN.diff \
    && echo " # Copy assets files ..." \
    && git checkout v10.7.5-zh \
    && cp -R locale ${GITLAB_DIR}/ \
    && mkdir -p ${GITLAB_DIR}/app \
    && cp -R app/assets ${GITLAB_DIR}/app/ \
    && mkdir -p ${GITLAB_DIR}/vendor \
    && cp -R vendor/assets ${GITLAB_DIR}/vendor/ \
	&& cp ../zh_CN.diff /etc/gitlab/
	
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/gems/mysql2-0.4.10 /opt/gitlab/embedded/lib/ruby/gems/2.3.0/gems/mysql2-0.4.10
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/gems/peek-mysql2-1.1.0 /opt/gitlab/embedded/lib/ruby/gems/2.3.0/gems/peek-mysql2-1.1.0

COPY --from=builderone /root/.gem /root/.gem

COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/cache/mysql2-0.4.10.gem /opt/gitlab/embedded/lib/ruby/gems/2.3.0/cache/mysql2-0.4.10.gem
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/cache/peek-mysql2-1.1.0.gem /opt/gitlab/embedded/lib/ruby/gems/2.3.0/cache/peek-mysql2-1.1.0.gem
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/doc/mysql2-0.4.10 /opt/gitlab/embedded/lib/ruby/gems/2.3.0/doc/mysql2-0.4.10
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/doc/mysql2-0.4.10/ri/ext/mysql2 /opt/gitlab/embedded/lib/ruby/gems/2.3.0/doc/mysql2-0.4.10/ri/ext/mysql2
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/extensions/x86_64-linux/2.3.0/mysql2-0.4.10 /opt/gitlab/embedded/lib/ruby/gems/2.3.0/extensions/x86_64-linux/2.3.0/mysql2-0.4.10
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/extensions/x86_64-linux/2.3.0/mysql2-0.4.10/mysql2 /opt/gitlab/embedded/lib/ruby/gems/2.3.0/extensions/x86_64-linux/2.3.0/mysql2-0.4.10/mysql2
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/extensions/x86_64-linux/2.3.0/mysql2-0.4.10/mysql2/mysql2.so /opt/gitlab/embedded/lib/ruby/gems/2.3.0/extensions/x86_64-linux/2.3.0/mysql2-0.4.10/mysql2/mysql2.so
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/specifications/mysql2-0.4.10.gemspec /opt/gitlab/embedded/lib/ruby/gems/2.3.0/specifications/mysql2-0.4.10.gemspec
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/specifications/peek-mysql2-1.1.0.gemspec /opt/gitlab/embedded/lib/ruby/gems/2.3.0/specifications/peek-mysql2-1.1.0.gemspec



RUN set -xe \
    && echo " # Regenerating the assets" \
    && cd ${GITLAB_DIR} \
	&& bundle config mirror.https://rubygems.org https://gems.ruby-china.org \
	&& bundle install --with=mysql
	
RUN set -xe \
    && echo " # Regenerating the assets" \
    && cd ${GITLAB_DIR} \
    && cp config/gitlab.yml.example config/gitlab.yml \
    && cp config/database.yml.postgresql config/database.yml \
    && cp config/secrets.yml.example config/secrets.yml \
    && rm -rf public/assets \
    && export NODE_ENV=production \
    && export RAILS_ENV=production \
    && export SETUP_DB=false \
    && export USE_DB=false \
    && export SKIP_STORAGE_VALIDATION=true \
    && export WEBPACK_REPORT=true \
    && export NO_COMPRESSION=true \
    && export NO_PRIVILEGE_DROP=true \
    && yarn install --frozen-lockfile \
    && bundle exec rake gettext:compile \
    && bundle exec rake gitlab:assets:compile

RUN set -xe \
    && echo " # Cleaning ..." \
    && yarn cache clean \
    && rm -rf log \
        tmp \
        config/gitlab.yml \
        config/database.yml \
        config/secrets.yml \
        .secret \
        .gitlab_shell_secret \
        .gitlab_workhorse_secret \
        app/assets \
        node_modules \
    && find /usr/lib/ -name __pycache__ | xargs rm -rf \
    && rm -rf /tmp/gitlab /tmp/*.diff /root/.cache /var/lib/apt/lists/*


######################
#  Production Stage  #
######################
FROM gitlab/gitlab-ce:10.7.5-ce.0 as production

RUN cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
(echo "deb-src http://archive.ubuntu.com/ubuntu bionic main restricted #Added by software-properties" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted" && \
echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic main restricted multiverse universe #Added by software-properties" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted" && \ 
echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted multiverse universe #Added by software-properties" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic universe" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-updates universe" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic multiverse" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-updates multiverse" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse" && \
echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse #Added by software-properties" && \
echo "deb http://archive.canonical.com/ubuntu bionic partner" && \
echo "deb-src http://archive.canonical.com/ubuntu bionic partner" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted" && \
echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted multiverse universe #Added by software-properties" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-security universe" && \
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-security multiverse") >/etc/apt/sources.list

RUN set -xe \
	&& sed -i "s/Port 22/Port 10022/" /assets/sshd_config \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -yqq locales tzdata mysql-client libmysqlclient-dev \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8
ENV TZ=Asia/Shanghai

ENV GITLAB_VERSION=v10.7.5
ENV GITLAB_DIR=/opt/gitlab/embedded/service/gitlab-rails
ENV GITLAB_GIT_ZH=https://gitlab.com/xhang/gitlab.git
ENV GITLAB_GIT_COMMIT_UPSTREAM=v10.7.5
ENV GITLAB_GIT_COMMIT_ZH=v10.7.5-zh

COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/gems/mysql2-0.4.10 /opt/gitlab/embedded/lib/ruby/gems/2.3.0/gems/mysql2-0.4.10
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/gems/peek-mysql2-1.1.0 /opt/gitlab/embedded/lib/ruby/gems/2.3.0/gems/peek-mysql2-1.1.0

COPY --from=builderone /root/.gem /root/.gem

COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/cache/mysql2-0.4.10.gem /opt/gitlab/embedded/lib/ruby/gems/2.3.0/cache/mysql2-0.4.10.gem
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/cache/peek-mysql2-1.1.0.gem /opt/gitlab/embedded/lib/ruby/gems/2.3.0/cache/peek-mysql2-1.1.0.gem
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/doc/mysql2-0.4.10 /opt/gitlab/embedded/lib/ruby/gems/2.3.0/doc/mysql2-0.4.10
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/doc/mysql2-0.4.10/ri/ext/mysql2 /opt/gitlab/embedded/lib/ruby/gems/2.3.0/doc/mysql2-0.4.10/ri/ext/mysql2
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/extensions/x86_64-linux/2.3.0/mysql2-0.4.10 /opt/gitlab/embedded/lib/ruby/gems/2.3.0/extensions/x86_64-linux/2.3.0/mysql2-0.4.10
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/extensions/x86_64-linux/2.3.0/mysql2-0.4.10/mysql2 /opt/gitlab/embedded/lib/ruby/gems/2.3.0/extensions/x86_64-linux/2.3.0/mysql2-0.4.10/mysql2
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/extensions/x86_64-linux/2.3.0/mysql2-0.4.10/mysql2/mysql2.so /opt/gitlab/embedded/lib/ruby/gems/2.3.0/extensions/x86_64-linux/2.3.0/mysql2-0.4.10/mysql2/mysql2.so
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/specifications/mysql2-0.4.10.gemspec /opt/gitlab/embedded/lib/ruby/gems/2.3.0/specifications/mysql2-0.4.10.gemspec
COPY --from=builderone /opt/gitlab/embedded/lib/ruby/gems/2.3.0/specifications/peek-mysql2-1.1.0.gemspec /opt/gitlab/embedded/lib/ruby/gems/2.3.0/specifications/peek-mysql2-1.1.0.gemspec

RUN set -xe \
    && echo " # Regenerating the assets" \
    && cd ${GITLAB_DIR} \
	&& bundle config mirror.https://rubygems.org https://gems.ruby-china.org \
	&& bundle install --with=mysql


COPY --from=builder ${GITLAB_DIR}/app                   ${GITLAB_DIR}/app
COPY --from=builder ${GITLAB_DIR}/public                ${GITLAB_DIR}/public
COPY --from=builder ${GITLAB_DIR}/config/application.rb ${GITLAB_DIR}/config/application.rb
COPY --from=builder ${GITLAB_DIR}/config/initializers   ${GITLAB_DIR}/config/initializers
COPY --from=builder ${GITLAB_DIR}/config/locales        ${GITLAB_DIR}/config/locales
COPY --from=builder ${GITLAB_DIR}/lib/gitlab            ${GITLAB_DIR}/lib/gitlab
COPY --from=builder ${GITLAB_DIR}/locale                ${GITLAB_DIR}/locale