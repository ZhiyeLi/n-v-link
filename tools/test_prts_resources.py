import unittest
from prts_resources import discover, safe_url


class ResourceDiscovery(unittest.TestCase):
    def test_public_assets_and_relative_urls(self):
        page = '<img src="//static.prts.wiki/model/a.png"><a href="/images/角色-Move.gif">clip</a>'
        found = discover(page, 'https://prts.wiki/w/角色')
        self.assertEqual(len(found), 2)
        self.assertIn('https://static.prts.wiki/model/a.png', found)
        self.assertTrue(any('Move.gif' in url for url in found))

    def test_ignores_scripts_and_external_trackers(self):
        self.assertEqual(discover('<script src="https://prts.wiki/a.js"></script><img src="https://example.com/x.png">', 'https://prts.wiki/'), [])

    def test_rejects_local_or_private_urls(self):
        for url in ['file:///C:/secret', 'http://localhost/a.png', 'https://prts.wiki.evil.test/a.png']:
            with self.assertRaises(ValueError): safe_url(url)


if __name__ == '__main__': unittest.main()
