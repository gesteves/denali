'use strict';

var fs          = require('fs');
var path        = require('path');
var cheerio     = require('gulp-cheerio');
var gulp        = require('gulp');
var rename      = require('gulp-rename');
var scsslint    = require('gulp-scss-lint');
var scssstylish = require('gulp-scss-lint-stylish');
var svgmin      = require('gulp-svgmin');
var replace     = require('gulp-replace');

var paths = {
  svg: ['app/assets/images/svg/*.svg'],
  sass: ['app/assets/stylesheets/**/*.scss', '!app/assets/stylesheets/vendors/*.scss']
};

// Lint Sass
gulp.task('sass', function() {
  return gulp.src(paths.sass)
    .pipe(scsslint({
      config: '.scss-lint.yml',
      bundleExec: true,
      customReport: scssstylish
    }));
});

// Clean SVG partials folder
function cleanSvgPartials() {
  var dir = 'app/views/partials/svg';
  if (fs.existsSync(dir)) {
    fs.readdirSync(dir).forEach(function(file) {
      if (file.endsWith('.html.erb')) {
        fs.unlinkSync(path.join(dir, file));
      }
    });
  }
}

// Minify and concatenate SVGs
// and save as a Rails partial
gulp.task('svg', function () {
  cleanSvgPartials();
  return gulp.src(paths.svg)
    .pipe(svgmin())
    .pipe(cheerio({
      run: function ($) {
        $('[style]').removeAttr('style');
        $('[fill]').removeAttr('fill');
        $('[stroke]').removeAttr('stroke');
      },
      parserOptions: { xmlMode: true }
    }))
    .pipe(cheerio({
      run: function ($) {
        $('svg').attr({
          'class': '{{{%= class_name %}}}',
          'aria-hidden': '{{{%= aria_hidden %}}}'
        });
        $('svg').removeAttr('xmlns');
      },
      parserOptions: { xmlMode: true }
    }))
    .pipe(replace('{{{', '<'))
    .pipe(replace('}}}', '>'))
    .pipe(rename(function(path) {
      path.basename = '_' + path.basename.replace(/-/g, '_');
      path.extname = '.html.erb';
    }))
    .pipe(gulp.dest('app/views/partials/svg'));
});

gulp.task('watch', function () {
  gulp.watch(paths.svg, gulp.series('svg'));
  gulp.watch(paths.sass, gulp.series('sass'));
});

gulp.task('default', gulp.series('watch'));
