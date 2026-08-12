const fs = require('fs');
const path = require('path');

// Force page content to top of AnimatedSwitcher via Positioned.fill + Align
{
  const file = path.join(__dirname, '..', 'lib/screens/admin/admin_layout.dart');
  let src = fs.readFileSync(file, 'utf8');
  const old = `                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<String>(_currentPage),
                    child: _buildPage(),
                  ),`;
  const neu = `                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null)
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: currentChild,
                            ),
                          ),
                      ],
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<String>(_currentPage),
                    child: _buildPage(),
                  ),`;
  if (!src.includes(old)) {
    console.error('FAIL layoutBuilder');
    process.exit(1);
  }
  fs.writeFileSync(file, src.replace(old, neu), 'utf8');
  console.log('OK layout top align');
}

{
  const file = path.join(__dirname, '..', 'lib/screens/admin/admin_theme.dart');
  let src = fs.readFileSync(file, 'utf8');
  src = src.replace(
    'static const double listPagePaddingTop = 8.0;',
    'static const double listPagePaddingTop = 4.0;',
  );
  fs.writeFileSync(file, src, 'utf8');
  console.log('OK padding 4');
}
