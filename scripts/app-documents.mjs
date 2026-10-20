import { copyFile, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

/** Copy maintained documents and derive their offline reading versions. */
export async function copyAppDocuments(projectRoot, resourcesPath) {
  const licence = await readFile(join(projectRoot, 'LICENSE'), 'utf8');
  const notice = await readFile(join(projectRoot, 'NOTICE'), 'utf8');
  const privacy = await readFile(join(projectRoot, 'PRIVACY.md'), 'utf8');
  const iconLicence = await readFile(join(projectRoot, 'assets', 'lucide-LICENSE.txt'), 'utf8');
  for (const name of ['LICENSE', 'NOTICE', 'PRIVACY.md']) {
    await copyFile(join(projectRoot, name), join(resourcesPath, name));
  }
  await writeFile(join(resourcesPath, 'Privacy.txt'), privacy
    .replace(/^#{1,6} /gm, '')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '$1 ($2)'));
  await writeFile(join(resourcesPath, 'Acknowledgements.txt'),
    `PanePeek acknowledgements\n\n${notice}\nApache License 2.0\n\n${licence}\nLucide and Feather icons\n\n${iconLicence}`);
}
