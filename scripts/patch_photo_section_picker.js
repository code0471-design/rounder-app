const fs = require('fs');
const path = require('path');

const file = path.join(
  __dirname,
  '..',
  'lib',
  'screens',
  'schedule',
  'schedule_screen.dart',
);

let src = fs.readFileSync(file, 'utf8');
let n = 0;

function replaceOnce(from, to, label) {
  const idx = src.indexOf(from);
  if (idx < 0) {
    console.error('missing:', label);
    process.exit(1);
  }
  src = src.slice(0, idx) + to + src.slice(idx + from.length);
  n += 1;
}

replaceOnce(
  "import '../records/score_award_screen.dart';\n",
  "import '../records/score_award_screen.dart';\nimport 'round_photo_widgets.dart';\n",
  'import',
);

replaceOnce(
  `                        const Text(
                          '라운딩 사진을 올려 추억을 남기세요',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // 사진 추가 버튼 (항상 표시)
                  GestureDetector(
                    onTap: () => _showUploadDialog(context, provider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.mintBright],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('사진 추가',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),`,
  `                        const Text(
                          '라운딩 사진을 올려 추억을 남기세요',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => _showUploadDialog(context, provider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.mintBright],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded,
                            color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('사진 추가',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),`,
  'photo header',
);

replaceOnce(
  `                            Image.network(
                              photo.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.divider,
                                child: const Icon(Icons.broken_image_outlined,
                                    color: AppColors.textSecondary),
                              ),
                            ),`,
  `                            RoundPhotoView(imageUrl: photo.imageUrl),`,
  'grid image',
);

const methodStart = src.indexOf(
  '  void _showUploadDialog(BuildContext context, ClubProvider provider) {',
);
const methodEnd = src.indexOf('\n\n// ── 일정 내 사진 뷰어');
if (methodStart < 0 || methodEnd < 0 || methodEnd <= methodStart) {
  console.error('missing upload dialog method', { methodStart, methodEnd });
  process.exit(1);
}
src =
  src.slice(0, methodStart) +
  `  void _showUploadDialog(BuildContext context, ClubProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PhotoUploadSheet(
        schedule: schedule,
        provider: provider,
      ),
    );
  }
}
` +
  src.slice(methodEnd);
n += 1;

replaceOnce(
  `              child: Image.network(
                widget.photos[i].imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white30, size: 60),
                ),
              ),`,
  `              child: RoundPhotoView(
                imageUrl: widget.photos[i].imageUrl,
                fit: BoxFit.contain,
                error: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white30, size: 60),
                ),
              ),`,
  'viewer image',
);

fs.writeFileSync(file, src, 'utf8');
console.log('patched', n, 'spots');
