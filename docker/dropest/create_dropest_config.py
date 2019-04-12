#!/usr/bin/env python

import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--whitelist')
parser.add_argument('--output')
parser.add_argument('--min_merge_fraction', default="0.2")
parser.add_argument('--max_cb_merge_edit_distance', default="2")
parser.add_argument('--max_umi_merge_edit_distance', default="1")
parser.add_argument('--min_genes_before_merge', default="20")
parser.add_argument('--cb', default="XC")
parser.add_argument('--umi', default="XM")
parser.add_argument('--gene', default="XG")
parser.add_argument('--cb_quality', default="CY")
parser.add_argument('--umi_quality', default="UY")

args = parser.parse_args()
with open(args.output, 'wt') as w:
    w.write('<config>')
    w.write('<Estimation>')
    w.write('<Merge>')
    if args.whitelist is not None:
        w.write('<barcodes_file>{}</barcodes_file>'.format(args.whitelist))
        w.write('<barcodes_type>const</barcodes_type>')
    w.write('<min_merge_fraction>{}</min_merge_fraction>'.format(args.min_merge_fraction))
    w.write('<max_cb_merge_edit_distance>{}</max_cb_merge_edit_distance>'.format(args.max_cb_merge_edit_distance))
    w.write('<max_umi_merge_edit_distance>{}</max_umi_merge_edit_distance>'.format(args.max_umi_merge_edit_distance))
    w.write('<min_genes_after_merge>100</min_genes_after_merge>')
    w.write('<min_genes_before_merge>{}</min_genes_before_merge>'.format(args.min_genes_before_merge))
    w.write('</Merge>')

    w.write('<PreciseMerge>')
    w.write('<max_merge_prob>1e-5</max_merge_prob>')
    w.write('<max_real_merge_prob>1e-7</max_real_merge_prob>')
    w.write('</PreciseMerge>')

    w.write('<BamTags>')
    w.write('<cb>{}</cb>'.format(args.cb))
    w.write('<umi>{}</umi>'.format(args.umi))
    w.write('<gene>{}</gene>'.format(args.gene))
    w.write('<cb_quality>{}</cb_quality>'.format(args.cb_quality))
    w.write('<umi_quality>{}</umi_quality>'.format(args.umi_quality))
    w.write('<Type>')
    w.write('<tag>XF</tag>')
    w.write('<intronic>INTRONIC</intronic>')
    w.write('<intergenic>INTERGENIC</intergenic>')
    w.write('</Type>')
    w.write('</BamTags>')
    w.write('</Estimation>')
    w.write('</config>')
